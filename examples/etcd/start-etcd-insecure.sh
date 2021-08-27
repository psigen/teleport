#!/bin/bash
# Copyright 2021 Gravitational, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Example of how etcd must be started in an insecure mode, i.e.
#   - server cert is NOT checked by clients
#   - client cert is NOT checked by the server
#
HERE=$(readlink -f $0)
cd "$(dirname $HERE)" || exit

mkdir -p data
etcd --name teleportstorage \
     --data-dir data/etcd \
     --initial-cluster-state new \
     --advertise-client-urls=http://127.0.0.1:2379 \
     --listen-client-urls=http://127.0.0.1:2379
