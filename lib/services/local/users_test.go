/*
Copyright 2021 Gravitational, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package local_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/gravitational/teleport/api/types"
	"github.com/gravitational/teleport/lib/backend/lite"
	"github.com/gravitational/teleport/lib/services/local"
	"github.com/gravitational/trace"
	"github.com/jonboulle/clockwork"
	"github.com/stretchr/testify/require"

	wantypes "github.com/gravitational/teleport/api/types/webauthn"
)

type cleanupFunc func()

func newIdentityService(t *testing.T) (*local.IdentityService, cleanupFunc) {
	t.Helper()
	ctx := context.Background()

	var path string
	cleanup := func() {
		if path != "" {
			_ = os.RemoveAll(path)
		}
	}

	path, err := os.MkdirTemp("" /* dir */, "users-test-" /* pattern */)
	require.NoError(t, err)

	backend, err := lite.NewWithConfig(ctx, lite.Config{
		Path:             path,
		PollStreamPeriod: 200 * time.Millisecond,
		Clock:            clockwork.NewFakeClock(),
	})
	if err != nil {
		cleanup()
		t.Fatal(err)
	}

	return local.NewIdentityService(backend), cleanup
}

func TestIdentityService_UpsertWebauthnLocalAuth(t *testing.T) {
	identity, cleanup := newIdentityService(t)
	defer cleanup()

	updateViaUser := func(ctx context.Context, user string, wal *types.WebauthnLocalAuth) error {
		u, err := types.NewUser(user)
		if err != nil {
			return err
		}
		las := u.GetLocalAuth()
		if las == nil {
			las = &types.LocalAuthSecrets{}
		}
		las.Webauthn = wal
		u.SetLocalAuth(las)

		err = identity.UpsertUser(u)
		return err
	}
	getViaUser := func(ctx context.Context, user string) (*types.WebauthnLocalAuth, error) {
		u, err := identity.GetUser(user, true /* withSecrets */)
		if err != nil {
			return nil, err
		}
		return u.GetLocalAuth().Webauthn, nil
	}

	// Create a user to begin with.
	const name = "llama"
	user, err := types.NewUser(name)
	require.NoError(t, err)
	err = identity.UpsertUser(user)
	require.NoError(t, err)

	// Try a few empty reads.
	ctx := context.Background()
	_, err = identity.GetUser(name, true /* withSecrets */)
	require.NoError(t, err) // User read should be fine.
	_, err = identity.GetWebauthnLocalAuth(ctx, name)
	require.True(t, trace.IsNotFound(err)) // Direct WAL read should fail.

	// Try a few invalid updates.
	badWAL := &types.WebauthnLocalAuth{} // missing UserID
	err = identity.UpsertWebauthnLocalAuth(ctx, name, badWAL)
	require.True(t, trace.IsBadParameter(err))
	user.SetLocalAuth(&types.LocalAuthSecrets{Webauthn: badWAL})
	err = identity.UpdateUser(ctx, user)
	require.True(t, trace.IsBadParameter(err))

	// Update/Read tests.
	tests := []struct {
		name   string
		user   string
		wal    *types.WebauthnLocalAuth
		update func(context.Context, string, *types.WebauthnLocalAuth) error
		get    func(context.Context, string) (*types.WebauthnLocalAuth, error)
	}{
		{
			name:   "OK: Create WAL directly",
			user:   "llama",
			wal:    &types.WebauthnLocalAuth{UserID: []byte("webauthn user ID for llama")},
			update: identity.UpsertWebauthnLocalAuth,
			get:    identity.GetWebauthnLocalAuth,
		},
		{
			name:   "OK: Update WAL directly",
			user:   "llama", // same as above
			wal:    &types.WebauthnLocalAuth{UserID: []byte("another ID")},
			update: identity.UpsertWebauthnLocalAuth,
			get:    identity.GetWebauthnLocalAuth,
		},
		{
			name:   "OK: Create WAL via user",
			user:   "alpaca", // new user
			wal:    &types.WebauthnLocalAuth{UserID: []byte("webauthn user ID for alpaca")},
			update: updateViaUser,
			get:    getViaUser,
		},
		{
			name:   "OK: Update WAL via user",
			user:   "alpaca", // same as above
			wal:    &types.WebauthnLocalAuth{UserID: []byte("some other ID")},
			update: updateViaUser,
			get:    getViaUser,
		},
	}
	for _, test := range tests {
		err := test.update(ctx, test.name, test.wal)
		require.NoError(t, err)

		want := test.wal
		got, err := test.get(ctx, test.name)
		require.NoError(t, err)
		if diff := cmp.Diff(want, got); diff != "" {
			t.Fatalf("WebauthnLocalAuth mismatch (-want +got):\n%s", diff)
		}
	}
}

func TestIdentityService_WebauthnSessionDataCRUD(t *testing.T) {
	identity, cleanup := newIdentityService(t)
	defer cleanup()

	const user1 = "llama"
	const user2 = "alpaca"
	// Prepare a few different objects so we can assert that both "user" and
	// "session" key components are used correctly.
	user1Reg := &wantypes.SessionData{
		Challenge: []byte("challenge1-reg"),
		UserId:    []byte("llamaid"),
	}
	user1Login := &wantypes.SessionData{
		Challenge:        []byte("challenge1-login"),
		UserId:           []byte("llamaid"),
		AllowCredentials: [][]byte{[]byte("cred1"), []byte("cred2")},
	}
	user2Login := &wantypes.SessionData{
		Challenge: []byte("challenge2"),
		UserId:    []byte("alpacaid"),
	}

	// Usually there are only 2 sessions for each user: login and registration.
	const registerSession = "register"
	const loginSession = "login"
	params := []struct {
		user, session string
		sd            *wantypes.SessionData
	}{
		{user: user1, session: registerSession, sd: user1Reg},
		{user: user1, session: loginSession, sd: user1Login},
		{user: user2, session: loginSession, sd: user2Login},
	}

	// Verify upsert/create.
	ctx := context.Background()
	for _, p := range params {
		err := identity.UpsertWebauthnSessionData(ctx, p.user, p.session, p.sd)
		require.NoError(t, err)
	}

	// Verify read.
	for _, p := range params {
		got, err := identity.GetWebauthnSessionData(ctx, p.user, p.session)
		require.NoError(t, err)
		if diff := cmp.Diff(p.sd, got); diff != "" {
			t.Fatalf("GetWebauthnSessionData() mismatch (-want +got):\n%s", diff)
		}
	}

	// Verify upsert/update.
	user1Reg = &wantypes.SessionData{
		Challenge: []byte("challenge1reg--another"),
		UserId:    []byte("llamaid"),
	}
	err := identity.UpsertWebauthnSessionData(ctx, user1, registerSession, user1Reg)
	require.NoError(t, err)
	got, err := identity.GetWebauthnSessionData(ctx, user1, registerSession)
	require.NoError(t, err)
	if diff := cmp.Diff(user1Reg, got); diff != "" {
		t.Fatalf("GetWebauthnSessionData() mismatch (-want +got):\n%s", diff)
	}

	// Verify deletion.
	err = identity.DeleteWebauthnSessionData(ctx, user1, registerSession)
	require.NoError(t, err)
	_, err = identity.GetWebauthnSessionData(ctx, user1, registerSession)
	require.True(t, trace.IsNotFound(err))
	params = params[1:] // Remove user1/register from params
	for _, p := range params {
		_, err := identity.GetWebauthnSessionData(ctx, p.user, p.session)
		require.NoError(t, err) // Other keys preserved
	}
}
