#!/bin/bash

cd /work/mycluster/mke

# Create a Service Account for MKE:
dcos security org service-accounts keypair mke-priv.pem mke-pub.pem
dcos security org service-accounts create -p mke-pub.pem -d 'Kubernetes service account' kubernetes
dcos security secrets create-sa-secret mke-priv.pem kubernetes kubernetes/sa

# Mesosphere Kubernetes Engine permissions:
dcos security org users grant kubernetes dcos:mesos:master:reservation:role:kubernetes-role create
dcos security org users grant kubernetes dcos:mesos:master:reservation:principal:kubernetes delete
dcos security org users grant kubernetes dcos:mesos:master:framework:role:kubernetes-role create
dcos security org users grant kubernetes dcos:mesos:master:task:user:nobody create

# Install MKE:
dcos package install --yes kubernetes --options=mke-options.json

Is_MKE_Ready1=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`
Is_MKE_Ready2=`dcos task | awk '$1 ~ /^kubernetes/' | awk '{print$4}'`

while :
do
	Is_MKE_Ready1=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`
	Is_MKE_Ready2=`dcos task | awk '$1 ~ /^kubernetes/' | awk '{print$4}'`

        if [[ -z "$Is_MKE_Ready1" || "$Is_MKE_Ready1" == "True" ]]
               then
                    echo "MKE is being installed, please wait ..."
                    sleep 10
		    Is_MKE_Ready1=`dcos marathon app list | grep "^/kubernetes"|awk '{print$7}'`
                    Is_MKE_Ready2=`dcos task | awk '$1 ~ /^kubernetes/' | awk '{print$4}'`
		    echo $Is_MKE_Ready2
	elif [[ $Is_MKE_Ready1 == "False" && $Is_MKE_Ready2 == "R" ]]
		then
	     		sleep 60
			echo "MKE should be ready now, let's install Kubernetes-cluster1 now"
                	break
        fi
done

cd /work/mycluster/k8sdcos

# Create K8s Service Account:
dcos security org service-accounts keypair kube1-priv.pem kube1-pub.pem
dcos security org service-accounts create -p kube1-pub.pem -d 'Service account for kubernetes-cluster1' kubernetes-cluster1
dcos security secrets create-sa-secret kube1-priv.pem kubernetes-cluster1 kubernetes-cluster1/sa

# Set permissions for the K8s Service Account:
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:task:user:root create
dcos security org users grant kubernetes-cluster1 dcos:mesos:agent:task:user:root create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:role:kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:principal:kubernetes-cluster1 delete
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:role:kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:principal:kubernetes-cluster1 delete
dcos security org users grant kubernetes-cluster1 dcos:secrets:default:/kubernetes-cluster1/* full
dcos security org users grant kubernetes-cluster1 dcos:secrets:list:default:/kubernetes-cluster1 read
dcos security org users grant kubernetes-cluster1 dcos:adminrouter:ops:ca:rw full
dcos security org users grant kubernetes-cluster1 dcos:adminrouter:ops:ca:ro full
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public/kubernetes-cluster1-role read
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:reservation:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:volume:role:slave_public/kubernetes-cluster1-role create
dcos security org users grant kubernetes-cluster1 dcos:mesos:master:framework:role:slave_public read
dcos security org users grant kubernetes-cluster1 dcos:mesos:agent:framework:role:slave_public read

# Install K8S in DC/OS:
dcos kubernetes cluster create --options=kubernetes1-options.json --yes
