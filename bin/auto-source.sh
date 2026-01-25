#!/bin/bash

set -feu

# input
image="$1"
trgt="${image}-eks-a-93"
# echo $trgt

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

AWS_REGION=ap-south-1

# images_list="public.ecr.aws/eks-anywhere/fluxcd/source-controller:v1.5.0-eks-a-93 \
# public.ecr.aws/eks-anywhere/fluxcd/notification-controller:v1.5.0-eks-a-93 \
# public.ecr.aws/eks-anywhere/fluxcd/kustomize-controller:v1.5.1-eks-a-93 \
# public.ecr.aws/eks-anywhere/fluxcd/helm-controller:v1.2.0-eks-a-93"

images_list="public.ecr.aws/eks-anywhere/fluxcd/source-controller:v1.7.0-eks-a-113 \
public.ecr.aws/eks-anywhere/fluxcd/notification-controller:v1.7.1-eks-a-113
public.ecr.aws/eks-anywhere/fluxcd/kustomize-controller:v1.7.0-eks-a-113
public.ecr.aws/eks-anywhere/fluxcd/helm-controller:v1.4.0-eks-a-113
"

# color
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

aws ecr get-login-password --region ap-south-1 \
| podman login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
echo 'logged in successfully'

for image in $images_list; do
  for image in $(cat $1 | grep "image:" | awk -F'image: ' '{print $2}')
  do
    trgt="${image}-eks-a-93"

    printf "${BLUE}push $image in $AWS_ACCOUNT_ID.../$image${NC}\n"
    # printf " -> crane copy $image $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/$image\n"
    # crane copy $image $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/$image

    podman pull $image
    podman tag $image \
      $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$trgt

    aws ecr create-repository \
      --region $AWS_REGION \
      --repository-name `echo eks/$trgt | cut -d: -f1`

    podman push \
      $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$trgt

    # printf "test\n"
    printf " -> ${GREEN}image $AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/eks/$image pushed with success\n"
  done
done
