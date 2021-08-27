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

// If you already have your own ACM certificate that you'd like to use, set the "use_acm" variable to "true" and then
// import the existing ACM certificate with:
// terraform import aws_acm_certificate.cert <certificate_arn>
// NOTE: using non-Amazon issued certificates in this manner is a bad idea as they cannot be automatically recreated by
// Terraform if they are deleted. In this instance we recommend setting up ACM on the proxy load balancer yourself.

// Define an ACM cert we can use for the proxy
resource "aws_acm_certificate" "cert" {
  domain_name       = var.route53_domain
  validation_method = "DNS"
  count             = var.use_acm ? 1 : 0

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.proxy.zone_id
  records = [tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60
  count   = var.use_acm ? 1 : 0
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
  count                   = var.use_acm ? 1 : 0
}
