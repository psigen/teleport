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

set -x

TCTL="/usr/local/bin/tctl --auth-server=proxy.luna.teleport:3025"
cd /mnt/shared/certs || exit 1

generate_certs() {
    $TCTL auth export --type=user | sed s/cert-authority\ // > ./teleport.pub || return
    $TCTL auth export --type=host | sed s/*.teleport/luna.teleport,*.luna.teleport,*.openssh.teleport/ > ./teleport-known_hosts.pub || return
    $TCTL create -f /etc/teleport.d/scripts/resources.yaml || return
    $TCTL auth sign --user=bot --format=openssh --out=bot --overwrite --ttl=10h || return
    $TCTL auth sign --user=bot --format=file --out=bot.pem --overwrite --ttl=10h || return
    $TCTL auth sign --user=editor --format=file --out=editor.pem --overwrite --ttl=10h || return
    $TCTL auth sign --host=mars.openssh.teleport --format=openssh --overwrite --out=mars.openssh.teleport || return
}

while true
do
    if generate_certs; then echo "Generated certs, exiting"; exit 0; fi;
    echo "Failed to generate certs, retry in a second";
    sleep 1;
done
