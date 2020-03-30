#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' #No Color
GREEN='\e[32m'
BLINK='\e[5m'

# Delete Kubernetes Cluster
# Check that 
dcos kubernetes cluster delete --cluster-name=kubernetes-cluster1 --yes &> /dev/null

Is_K8S_Cluster_Uninstalled=`dcos marathon app show /kubernetes-cluster1`
dcos marathon app show /kubernetes-cluster1 &> /dev/null

until [[ $? -eq "1" ]]; do
	printf "${BLINK}${RED}Uninstalling Kubernetes-cluster1${NC}\n"
	sleep 30
	dcos marathon app show /kubernetes-cluster1 &> /dev/null
done

printf "${RED}Kubernetes-cluster1 has been uninstalled${NC}\n"

# Delete Kubernetes Cluster Service Account
dcos security org service-accounts delete kubernetes-cluster1
dcos security secrets delete kubernetes-cluster1/sa

printf "${RED}Kubernetes-cluster1 service account and permissions have been deleted${NC}\n"

# Delete MKE
dcos package uninstall kubernetes --yes &> /dev/null

dcos marathon app show /kubernetes &> /dev/null

until [[ $? -eq "1" ]]; do
        printf "${RED}Uninstalling MKE${NC}\n"
	sleep 30
	dcos marathon app show /kubernetes &> /dev/null
done

printf "${RED}MKE has been uninstalled${NC}\n"

# Delete the MKE Service Account:
dcos security org service-accounts delete kubernetes
dcos security secrets delete kubernetes/sa

printf "${RED}MKE service account and permissions have been deleted${NC}\n"

