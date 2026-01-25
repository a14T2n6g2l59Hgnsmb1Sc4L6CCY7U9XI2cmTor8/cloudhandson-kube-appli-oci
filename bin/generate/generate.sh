#!/bin/bash

set -feu

export CLUSTER_ENV="$1"
export CLUSTER_NAME="$2"

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export AWS_REGION="ap-south-1"

applications_list=$(
  gh repo list "$GH_ORG" \
    --no-archived \
    --limit 300 \
    --json name,repositoryTopics |
  jq -r \
    --arg CLUSTER_ENV "$CLUSTER_ENV" \
    --arg CLUSTER_NAME "$CLUSTER_NAME" \
    '.[] |
     (.repositoryTopics // []) as $topics |
     select(
       ($topics | map(.name) | index($CLUSTER_ENV)) and
       ($topics | map(.name) | index($CLUSTER_NAME))
     ) |
     .name |
     sub("^cloudhandson-kube-"; "")
'
)

echo "$applications_list"

for application in $applications_list
do
  echo "########## START FOR Application: $application"

  export APPLICATION_NAME="$application"
  export APPLICATION_NAMESPACE="$APPLICATION_NAME"

  export SPLUNK_EFS_ID=$(aws efs describe-file-systems \
    --query "FileSystems[?Name=='eks-${CLUSTER_NAME}-${CLUSTER_ENV}-splunk-efs'].FileSystemId" \
    --output text)

  export SPLUNK_ACCESS_POINT_ID=$(aws efs describe-access-points \
    --query "AccessPoints[?Name=='${APPLICATION_NAMESPACE}-splunk-access-point' && FileSystemId=='${SPLUNK_EFS_ID}'].AccessPointId" \
    --output text)

  export DATA_EFS_ID=$(aws efs describe-file-systems \
    --query "FileSystems[?Name=='eks-${CLUSTER_NAME}-${CLUSTER_ENV}-data-efs'].FileSystemId" \
    --output text)

  export DATA_ACCESS_POINT_ID=$(aws efs describe-access-points \
    --query "AccessPoints[?Name=='${APPLICATION_NAMESPACE}-data-access-point' && FileSystemId=='${DATA_EFS_ID}'].AccessPointId" \
    --output text)

  mkdir -p resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME

  cat bin/generate/templates/ks.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/ks.yaml

  cat bin/generate/templates/ks_app.yaml | envsubst \
    >> resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/ks.yaml

  cat bin/generate/templates/ocirepo.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/ocirepo.yaml

  cat bin/generate/templates/namespace.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/namespace.yaml

  cat bin/generate/templates/gw.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/gw.yaml

  cat bin/generate/templates/secretstore.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/secretstore.yaml

  cat bin/generate/templates/serviceaccount.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/serviceaccount.yaml

  cat bin/generate/templates/persistentvolume.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/persistentvolume.yaml

  cat bin/generate/templates/persistentvolumeclaim.yaml | envsubst \
    > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/persistentvolumeclaim.yaml

  export EFS_SHARED_NAME=$(gh repo view "$GH_ORG/cloudhandson-kube-$APPLICATION_NAME" \
    --json repositoryTopics |
    jq -r '.repositoryTopics[] | select(.name | contains("efs-shared-")) | .name | sub("efs-shared-"; "")'
  )

  if [ -n "$EFS_SHARED_NAME" ]; then
    export EFS_PERIMETER_ACCESS_POINT_ID=$(aws efs describe-access-points \
      --query "AccessPoints[?Name=='shared-${EFS_SHARED_NAME}-global-access-point' && FileSystemId=='${DATA_EFS_ID}'].AccessPointId" \
      --output text)

    cat bin/generate/templates/shared_pv_pvc.yaml | envsubst \
      > resources-generated/$CLUSTER_ENV/$CLUSTER_NAME/$APPLICATION_NAMESPACE/$APPLICATION_NAME/shared_pv_pvc.yaml
  fi
done
