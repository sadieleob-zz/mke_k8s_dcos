#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
#printf "I ${RED}love${NC} Stack Overflow\n"

Is_MKE_Ready=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`

while :
do
	#Is_MKE_Ready=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`
	Is_MKE_Ready=`dcos marathon app show /kubernetes | jq '.tasksHealthy'`
	echo $Is_MKE_Ready
	#echo $?
        #if [[ -z "$Is_MKE_Ready" || "$Is_MKE_Ready" == "True" ]]
        if [[ "$Is_MKE_Ready" -eq "1" ]]
               then
                    echo "MKE has been installed and is healthy"
                    #sleep 10
		    #Is_MKE_Ready=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`
		    break
	else 
	    [ $Is_MKE_Ready == "False" ]
		echo "MKE is being installed or not healthy yet"
                printf "${RED}...${NC}\n"
		sleep 30
                
        fi
done

