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

// SSM parameters are populated by default, and
// are here to make sure they will get deleted after cluster
// is destroyed, cluster will overwrite them with real values

resource "aws_ssm_parameter" "license" {
  count     = var.license_path != "" ? 1 : 0
  name      = "/teleport/${var.cluster_name}/license"
  type      = "SecureString"
  value     = file(var.license_path)
  overwrite = true
}

resource "aws_ssm_parameter" "grafana_pass" {
  name      = "/teleport/${var.cluster_name}/grafana_pass"
  type      = "SecureString"
  value     = var.grafana_pass
  overwrite = true
}

