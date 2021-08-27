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

// Example route53 zone for automation purposes
// used to provision public DNS name for proxy
data "aws_route53_zone" "proxy" {
  name = var.route53_zone
}

// Route53 record connects proxy network load balancer
// letsencrypt
resource "aws_route53_record" "proxy" {
  zone_id = data.aws_route53_zone.proxy.zone_id
  name    = var.route53_domain
  type    = "A"
  count   = var.use_acm ? 0 : 1

  alias {
    name                   = aws_lb.proxy.dns_name
    zone_id                = aws_lb.proxy.zone_id
    evaluate_target_health = true
  }
}

// ACM (ALB)
resource "aws_route53_record" "proxy_acm" {
  zone_id = data.aws_route53_zone.proxy.zone_id
  name    = var.route53_domain
  type    = "A"
  count   = var.use_acm ? 1 : 0

  alias {
    name                   = aws_lb.proxy_acm[0].dns_name
    zone_id                = aws_lb.proxy_acm[0].zone_id
    evaluate_target_health = true
  }
}

// ACM (NLB)
resource "aws_route53_record" "proxy_acm_nlb_alias" {
  zone_id = data.aws_route53_zone.proxy.zone_id
  name    = var.route53_domain_acm_nlb_alias
  type    = "A"
  count   = var.use_acm ? var.route53_domain_acm_nlb_alias != "" ? 1 : 0 : 0

  alias {
    name                   = aws_lb.proxy.dns_name
    zone_id                = aws_lb.proxy.zone_id
    evaluate_target_health = true
  }
}
