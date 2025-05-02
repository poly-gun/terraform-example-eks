#!/bin/bash

# -*-  Coding: UTF-8  -*- #
# -*-  System: Linux  -*- #
# -*-  Usage:   *.*   -*- #

# See Bash Set-Options Reference Below

set -euo pipefail # (0)
set -o xtrace     # (6)

# --------------------------------------------------------------------------------
# Bash Set-Options Reference
#     - https://tldp.org/LDP/abs/html/options.html
# --------------------------------------------------------------------------------

# 0. An Opinionated, Well Agreed Upon Standard for Bash Script Execution
# 1. set -o verbose     ::: Print Shell Input upon Read
# 2. set -o allexport   ::: Export all Variable(s) + Function(s) to Environment
# 3. set -o errexit     ::: Exit Immediately upon Pipeline'd Failure
# 4. set -o monitor     ::: Output Process-Separated Command(s)
# 5. set -o privileged  ::: Ignore Externals - Ensures of Pristine Run Environment
# 6. set -o xtrace      ::: Print a Trace of Simple Commands
# 7. set -o braceexpand ::: Enable Brace Expansion
# 8. set -o no-exec     ::: Bash Syntax Debugging

function main() {
    local KEY="Polygun-Administration"

    [[ -f ~/.ssh/${KEY} ]] && cp -f ~/.ssh/${KEY} .
    [[ -f ~/.ssh/${KEY} ]] || ssh-keygen -t ed25519 -C "administration@polygun.com" -f "${KEY}" -q -N ""
    [[ -f ~/.ssh/${KEY} ]] || ( cp "${KEY}" ~/.ssh && cp "${KEY}.pub" ~/.ssh )

    local REGIONS="$(aws ec2 describe-regions --query "Regions[].RegionName" --output text --no-cli-auto-prompt --no-cli-pager)"

    for REGION in ${REGIONS}; do
        aws ec2 import-key-pair --key-name "${KEY}" --public-key-material "fileb://${KEY}.pub" --region "${REGION}" --no-cli-auto-prompt --no-cli-pager || true
    done

    echo "Ensure to Base64 Encode the Public Key Content and Update .env for API"
}

main
