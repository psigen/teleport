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

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Please specify at least one kubeconfig file."
    exit 1
fi

# Join script arguments with a ":" using bash magic.
IFS=":"
export KUBECONFIG="$*"

# When $KUBECONFIG contains a list of files, kubectl will merge them.
kubectl config view --raw >merged-kubeconfig

echo "Wrote merged-kubeconfig.

Copy the generated kubeconfig file to your Teleport Proxy server, and set the
kubeconfig_file parameter in your teleport.yaml config file to point to this
kubeconfig file."
