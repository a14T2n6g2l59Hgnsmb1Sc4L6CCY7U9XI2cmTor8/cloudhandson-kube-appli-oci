#!/bin/bash

set -feu

# Global Variables
export GH_ORG="a14T2n6g2l59Hgnsmb1Sc4L6CCY7U9XI2cmTor8"
export GITHUB_TOKEN=""

# Exec Variables
export clusters_list="common"
export envs_list="lab
dev"
# qa
# prep
# prod

# Clean local repo
rm -rf resources-generated

# Generate yaml file
for env in $envs_list
do
  for cluster in $clusters_list
  do
    bash ./bin/generate/generate.sh $env $cluster
  done
done
