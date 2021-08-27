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

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "base" {
  most_recent = true
  owners      = [126027368216]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

data "aws_route53_zone" "cluster" {
  name = var.route53_zone
}

data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
  name = var.region
}

data "aws_availability_zones" "available" {
}

// SSM is picking alias for key to use for encryption in SSM
data "aws_kms_alias" "ssm" {
  name = var.kms_alias_name
}
