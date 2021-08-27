#!/bin/bash
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


until curl --output /dev/null --silent --head --fail http://grafana:3000; do
    echo 'waiting for grafana to respond'
    sleep 5
done

echo "grafana is up setting up dashboards and data sources"

curl -s -H "Content-Type: application/json" \
    -XPOST http://admin:admin@grafana:3000/api/datasources \
    -d @- <<EOF
{
    "name": "InfluxDB",
    "type": "influxdb",
    "access": "proxy",
    "url": "http://influxdb:8086",
    "database": "telegraf"
}
EOF

curl -X POST -d @/mnt/health-dashboard.json 'http://admin:admin@grafana:3000/api/dashboards/db' --header 'Content-Type: application/json'

echo "all done!"
