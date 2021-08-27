/**
 * Copyright 2021 Gravitational, Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Bastion is an emergency access bastion
// that could be spinned up on demand in case if
// of need to have emrergency administrative access
resource "aws_instance" "bastion" {
  count                       = "1"
  ami                         = data.aws_ami.base.id
  instance_type               = "t2.medium"
  key_name                    = var.key_name
  associate_public_ip_address = true
  source_dest_check           = false
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = element(aws_subnet.public.*.id, 0)
  tags = {
    TeleportCluster = var.cluster_name
    TeleportRole    = "bastion"
  }
}

// Bastions are open to internet access
resource "aws_security_group" "bastion" {
  name   = "${var.cluster_name}-bastion"
  vpc_id = local.vpc_id
  tags = {
    TeleportCluster = var.cluster_name
  }
}

// Ingress traffic is allowed to SSH 22 port only
resource "aws_security_group_rule" "bastion_ingress_allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

// Egress traffic is allowed everywhere
resource "aws_security_group_rule" "proxy_egress_bastion_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

