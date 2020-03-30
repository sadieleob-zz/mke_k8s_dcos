#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\e[32m'
BLINK='\e[5m'
YELLOW='\e[93m'

printf "${GREEN}Kubernetes cluster 1 is being installed${NC} ... ${RED}${BLINK}please wait ${NC}\n"
seconds=0
#dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 &> /dev/null

dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 &> /dev/null

until [[ $? -eq "0" ]]; do 
  seconds=$((seconds+30))
  printf "${GREEN}You have been waiting %s seconds for this Kubernetes deployment to complete. We will start providing details on deployment phases shortly.${NC}\n" "$seconds" 
  dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 &> /dev/null
  sleep 30
done

if [[ $? -eq "0" ]] 
then
  echo $?
  printf "${RED}PHASE${NC}             ${RED}STATUS${NC}\n" && 
  dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 --json | grep -vi 'Using Kubernetes cluster' | jq -r '"\(.phases[] | .name + " " + .status)"' | column -t
  sleep 10
  dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 &> /dev/null
fi

if [[ $(dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 | grep -vi 'Using Kubernetes cluster' | head -n 1) == "deploy (serial strategy) (COMPLETE)" ]]
then    
  printf "${GREEN}Kubernetes cluster1 has been deployed successfully${NC}\n"
fi 

#printf "${RED}Kubernetes deployment completed.${NC}"
