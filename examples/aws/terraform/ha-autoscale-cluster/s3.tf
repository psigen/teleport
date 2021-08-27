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

// S3 bucket is used to distribute letsencrypt certificates
resource "aws_s3_bucket" "certs" {
  bucket        = var.s3_bucket_name
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_object" "grafana_teleport_dashboard" {
  bucket = aws_s3_bucket.certs.bucket
  key    = "health-dashboard.json"
  source = "./assets/health-dashboard.json"
}

// Grafana nginx config (letsencrypt)
resource "aws_s3_bucket_object" "grafana_teleport_nginx" {
  bucket = aws_s3_bucket.certs.bucket
  key    = "grafana-nginx.conf"
  source = "./assets/grafana-nginx.conf"
  count  = var.use_acm ? 0 : 1
}

// Grafana nginx config (ACM)
resource "aws_s3_bucket_object" "grafana_teleport_nginx_acm" {
  bucket = aws_s3_bucket.certs.bucket
  key    = "grafana-nginx.conf"
  source = "./assets/grafana-nginx-acm.conf"
  count  = var.use_acm ? 1 : 0
}

