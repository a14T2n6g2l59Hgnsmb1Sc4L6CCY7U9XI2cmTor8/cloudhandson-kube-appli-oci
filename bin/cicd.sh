#!/bin/bash

# usage:
# bash ./bin/cicd.sh $CLUSTER_ENV $CLUSTER_NAME [push]

action="$3"
set -feu

export CLUSTER_ENV="$1"
export CLUSTER_NAME="$2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export AWS_REGION="ap-south-1"
export AWS_ECR_REPOSITORY="eks/config/$CLUSTER_ENV/$CLUSTER_NAME/tooling/appli-oci"

# step 0 : clean local repo
rm -rf generated deployed
mkdir -p generated deployed

# step 0.5 : pre-build
bash bin/generate/generate.sh $CLUSTER_ENV $CLUSTER_NAME $AWS_ACCOUNT_ID

cat kustomization.tpl.yaml | envsubst \
  '${CLUSTER_ENV},${CLUSTER_NAME},${AWS_ACCOUNT_ID}' \
  > kustomization.yaml

# step 1 : Generate configuration
kustomize build --enable-helm \
| envsubst '${AWS_ACCOUNT_ID},${AWS_REGION},${CLUSTER_ENV},${CLUSTER_NAME}' \
> generated/manifests.yaml

# step 2 : Validate yaml
kubeconform \
  -summary \
  -skip CustomResourceDefinition,Kustomization,OCIRepository,Gateway,SecretStore \
  generated/

aws ecr get-login-password --region ap-south-1 \
| docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Step 3 : Push Artifact => remetre les refs vers git
if [ "$action" = "push" ]; then
  flux push artifact oci://$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPOSITORY:latest \
    --path="./generated/" \
    --source="$(git config --get remote.origin.url)" \
    --revision="$(git tag --points-at HEAD)@sha1:$(git rev-parse HEAD)" \
    --provider aws
else
  # Step 3 : Get Diff
  flux pull artifact oci://$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$AWS_ECR_REPOSITORY:latest \
    --output deployed \
    --provider aws

  diff -u deployed/manifests.yaml generated/manifests.yaml | colordiff
fi
