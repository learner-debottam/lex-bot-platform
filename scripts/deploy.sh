#!/bin/bash
set -e

ENV=$1

echo "Deploying to $ENV"

terraform -chdir=infra init -backend-config="state/${ENV}.config"
terraform -chdir=infra apply \
  -var-file="vars/${ENV}.tfvars" \
  -auto-approve