#!/bin/bash

set -feu

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

AWS_REGION=ap-south-1

flux_operator="ghcr.io/controlplaneio-fluxcd/flux-operator:v0.18.0"

flux_cd="ghcr.io/fluxcd"

# color
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

aws ecr get-login-password --region ap-south-1 \
| docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
echo 'logged in successfully'

printf "${BLUE}push $flux_operator in $AWS_ACCOUNT_ID.../$flux_operator${NC}\n"
docker pull $flux_operator
docker tag $flux_operator \
  $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$flux_operator

# aws ecr create-repository \
#   --region $AWS_REGION \
#   --repository-name `echo eks/$flux_operator | cut -d: -f1`

docker push \
  $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$flux_operator

# printf "test\n"
printf " -> ${GREEN}flux_operator $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$flux_operator pushed with success\n"
