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

ARG TELEPORT_TAG
FROM quay.io/gravitational/teleport:${TELEPORT_TAG}

# Demo ansible, ssh, htop
RUN apt-get update && apt-get install -y ansible ssh inetutils-syslogd htop

RUN mkdir /run/sshd

VOLUME ["/teleport", "/var/lib/teleport"]

COPY ./etc/teleport.yaml /etc/teleport.d/teleport.yaml
COPY ./.bashrc /root/.bashrc
COPY ./.screenrc /root/.screenrc
COPY ./scripts /etc/teleport.d/scripts
COPY ./ansible /etc/teleport.d/ansible
COPY ./pam.d/ssh /etc/pam.d/ssh
COPY ./etc/ssh/sshd_config /etc/ssh/sshd_config
