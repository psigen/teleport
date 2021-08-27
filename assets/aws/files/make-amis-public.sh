#!/usr/bin/env bash
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

set -e

# Exit if required parameters not provided
if [[ "$1" == "" ]] || [[ "$2" == "" ]]; then
    echo "Usage: $(basename $0) [oss/ent/ent-fips] [comma-separated-destination-region-list]"
    exit 1
else
    RUN_MODE="$1"
    REGION_LIST="$2"
fi

# Note: to run this script on MacOS you will need to install coreutils (using Brew), then edit the PATH in your shell's
# RC file to use coreutils versions first (something like "export PATH=/usr/local/opt/coreutils/libexec/gnubin:$PATH")
ABSPATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "${ABSPATH}")
BUILD_DIR=$(readlink -f "${SCRIPT_DIR}/build")

AMI_TAG="production"
OUTFILE="amis.txt"
BUILD_TIMESTAMP_FILENAME="${RUN_MODE}_build_timestamp.txt"
NAME_FILTER="*${RUN_MODE}*"
# Conditionally set variables for FIPS
if [[ "${RUN_MODE}" == "ent-fips" ]]; then
    AMI_TAG="production-fips"
    OUTFILE="amis-fips.txt"
    BUILD_TIMESTAMP_FILENAME="ent_build_timestamp.txt"
    NAME_FILTER="*-fips"
fi

# Remove existing AMI ID file if present
if [ -f "${BUILD_DIR}/${OUTFILE}.txt" ]; then
    rm -f "${BUILD_DIR}/${OUTFILE}.txt"
fi

# Read build timestamp from file
TIMESTAMP_FILE="${BUILD_DIR}/${BUILD_TIMESTAMP_FILENAME}"
if [ ! -f "${TIMESTAMP_FILE}" ]; then
    echo "Cannot find \"${TIMESTAMP_FILE}\""
    exit 1
fi
BUILD_TIMESTAMP=$(<"${TIMESTAMP_FILE}")

# Iterate through AMIs
IFS=","
for REGION in ${REGION_LIST}; do
    AMI_ID=$(aws ec2 describe-images --region ${REGION} --filters "Name=name,Values=${NAME_FILTER}" "Name=tag:BuildTimestamp,Values=${BUILD_TIMESTAMP}" "Name=tag:BuildType,Values=${AMI_TAG}"| jq -r '.Images[0].ImageId')
    if [[ "${AMI_ID}" == "" || "${AMI_ID}" == "null" ]]; then
        echo "Error: cannot get AMI ID for ${REGION}"
        exit 2
    fi
    # Make each AMI public (set launchPermission to 'all')
    aws ec2 modify-image-attribute --region ${REGION} --image-id ${AMI_ID} --launch-permission "Add=[{Group=all}]"
    # Check that the AMI was successfully made public by listing it again
    # The output will be "true" if the AMI is public and "" if it doesn't exist or is private
    PUBLIC_CHECK=$(aws ec2 describe-images --region ${REGION} --filters "Name=image-id,Values=${AMI_ID}" "Name=is-public,Values=true" | jq -r '.Images[].Public')
    if [[ "${PUBLIC_CHECK}" == "true" ]]; then
        echo "AMI ID ${AMI_ID} for ${REGION} set to public"
    else
        echo "WARNING: There was an error making ${AMI_ID} in ${REGION} public!"
    fi
done
