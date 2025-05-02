#!/bin/bash --posix

# -*-  Coding: UTF-8  -*- #
# -*-  System: Linux  -*- #
# -*-  Usage:   *.*   -*- #

# Author: Jacob B. Sanders

# --------------------------------------------------------------------------------
# Bash Set-Options Reference
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

set -euo pipefail # (0)

set -o xtrace

yum update -y && yum upgrade -y
yum group install -y "Development Tools"
yum install -y wget bash jq zip unzip git

export AWS_DEFAULT_REGION="${AWS-Region}"

# git config --global user.name "git"

function awscli () {
    aws configure set
}

function g {
    curl -L "https://go.dev/dl/go1.21.1.linux-arm64.tar.gz" --output go.tar.gz

    rm -rf /usr/local/go && rm -rf rm -rf /usr/bin/go

    tar -C /usr/local -xzf go.tar.gz

    export PATH="$${PATH}:/usr/local/go/bin"

    grep -Rq "/usr/local/go/bin" /etc/bashrc || echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/bashrc

    export HOME=/root && export GOPATH=/root/go
}

function tls {
    mkdir -p /opt/tls

    curl -L "https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem" --output /opt/tls/rds-ca-2019-root.pem
    curl -L "https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem" --output /opt/tls/rds-combined-ca-bundle.pem
}

function k8s {
    curl -L https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.4/2023-08-16/bin/linux/arm64/kubectl --output kubectl
    mv kubectl /usr/local/bin/kubectl
    chmod -v +x /usr/local/bin/kubectl

    # aws eks update-kubeconfig --region us-east-2 --name IaC-Development-Nexus-K8s-Cluster
}

function containers {
    yum install -y docker

    usermod -a -G docker ec2-user

    curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) --output docker-compose
    mv docker-compose /usr/local/bin/docker-compose
    chmod -v +x /usr/local/bin/docker-compose

    systemctl enable docker.service
    systemctl start docker.service
    systemctl status docker.service --no-pager

    yum install -y amazon-ecr-credential-helper

    mkdir -p /root/.docker
    mkdir -p /home/ec2-user/.docker

    echo '{"credsStore": "ecr-login"}' > /root/.docker/config.json
    echo '{"credsStore": "ecr-login"}' > /home/ec2-user/.docker/config.json

    chmod -R 755 /home/ec2-user/.docker

    chown -R ec2-user:docker /home/ec2-user/.docker
}

function identifier {
    echo "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
}

function main {
    g
    tls
    containers

    k8s
}

main
