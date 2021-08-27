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

# The base image (buildbox:latest) is built by running `make -C build.assets`
# from the base repo directory $GOPATH/gravitational.com/teleport
FROM quay.io/gravitational/teleport-buildbox:go1.15.5

# DEBUG=1 is needed for the Web UI to be loaded from static assets instead
# of the binary
ENV DEBUG=1 GOPATH=/root/go PATH=$PATH:/root/go/src/github.com/gravitational/teleport/build:/root/go/bin

# htop is useful for testing terminal resizing
RUN apt-get update && \
    apt-get install -y htop vim screen && \
    mkdir -p /root/go/src/github.com/gravitational/teleport

# allows ansible and ssh testing
RUN apt-get install -y ansible ssh inetutils-syslogd

RUN mkdir /run/sshd

VOLUME ["/teleport", "/var/lib/teleport"]
COPY ./sshd/bashrc /root/.bashrc
COPY ./sshd/screenrc /root/.screenrc
COPY ./sshd/scripts/start-sshd.sh /usr/bin/start-sshd.sh

# expose only proxy ports (SSH and HTTPS)
EXPOSE 3023 3080
