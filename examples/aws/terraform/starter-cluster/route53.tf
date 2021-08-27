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

/*
Route53 is used to configure SSL for this cluster. A
Route53 hosted zone must exist in the AWS account for
this automation to work.
*/

// Create A record to instance IP
resource "aws_route53_record" "cluster" {
  zone_id = data.aws_route53_zone.cluster.zone_id
  name    = var.route53_domain
  type    = "A"
  ttl     = "300"
  records = [aws_instance.cluster.public_ip]
}
