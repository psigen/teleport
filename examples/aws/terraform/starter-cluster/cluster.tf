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

// Configuration data for teleport.yaml generation
data "template_file" "node_user_data" {
  template = file("data.tpl")

  vars = {
    region                   = var.region
    cluster_name             = var.cluster_name
    email                    = var.email
    domain_name              = var.route53_domain
    dynamo_table_name        = aws_dynamodb_table.teleport.name
    dynamo_events_table_name = aws_dynamodb_table.teleport_events.name
    locks_table_name         = aws_dynamodb_table.teleport_locks.name
    license_path             = var.license_path
    s3_bucket                = var.s3_bucket_name
    use_acm                  = var.use_acm
    use_letsencrypt          = var.use_letsencrypt
  }
}

// Auth, node, proxy (aka Teleport Cluster) on single AWS instance
resource "aws_instance" "cluster" {
  key_name                    = var.key_name
  ami                         = data.aws_ami.base.id
  instance_type               = var.cluster_instance_type
  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  associate_public_ip_address = true
  user_data                   = data.template_file.node_user_data.rendered
  iam_instance_profile        = aws_iam_role.cluster.id
}

