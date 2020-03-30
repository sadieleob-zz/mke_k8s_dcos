#!/usr/bin/env bash

dcos package install --yes dcos-enterprise-cli

dcos security org service-accounts keypair mke-priv.pem mke-pub.pem
dcos security org service-accounts create -p mke-pub.pem -d 'Kubernetes service account' kubernetes
dcos security secrets create-sa-secret mke-priv.pem kubernetes kubernetes/sa

dcos security org users grant kubernetes dcos:mesos:master:reservation:role:kubernetes-role create
dcos security org users grant kubernetes dcos:mesos:master:framework:role:kubernetes-role create
dcos security org users grant kubernetes dcos:mesos:master:task:user:nobody create

cat > mke-options.json << EOF
{
    "service": {
        "service_account": "kubernetes",
        "service_account_secret": "kubernetes/sa"
    }
}
EOF

dcos package install --yes kubernetes --options=mke-options.json --package-version=2.4.6-1.15.6

sleep 30

dcos security org service-accounts keypair kube1-priv.pem kube1-pub.pem
dcos security org service-accounts create -p kube1-pub.pem -d 'Service account for kubernetes-cluster1' kubernetes-cluster1
dcos security secrets create-sa-secret kube1-priv.pem kubernetes-cluster1 kubernetes-cluster1/sa

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

cat > kubernetes1-options.json << EOF
{
    "service": {
        "name": "kubernetes-cluster1",
        "service_account": "kubernetes-cluster1",
        "service_account_secret": "kubernetes-cluster1/sa"
    }
}
EOF

# cat > kubernetes1-options.json << EOF
# {
#     "service": {
#         "name": "kubernetes-cluster1",
#         "service_account": "kubernetes-cluster1",
#         "service_account_secret": "kubernetes-cluster1/sa"
#     },
#     "kubernetes": {
#         "private_node_count": 4,
#         "high_availability": true
#     }
# }
# EOF


dcos kubernetes cluster create --options=kubernetes1-options.json --yes

echo -e "Cluster is deploying. Please run the following command to monitor its progress:\ndcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1"


echo "Monitoring Kubernetes deployment until complete..."
seconds=0
until [[ $(dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 | grep -vi 'Using Kubernetes cluster' | head -n 1) == "deploy (serial strategy) (COMPLETE)" ]]; do
  seconds=$((seconds+30))
  printf "Waiting %s seconds for Kubernetes deployment to complete. Please allow at least 400s for completion.\n" "$seconds"
  (echo -e "PHASE STATUS"
  dcos kubernetes cluster debug plan status deploy --cluster-name=kubernetes-cluster1 --json | grep -vi 'Using Kubernetes cluster' | jq -r '"\(.phases[] | .name + " " + .status)"') | column -t
  sleep 30
done
echo "Kubernetes deployment completed."

# echo "Installing marathon-lb..."
# dcos package install --yes marathon-lb

sleep 15

# cat > kubectl-proxy.json << EOF
# {
#   "id": "/nokia-cluster1-kubectl-proxy",
#   "instances": 1,
#   "cpus": 0.001,
#   "mem": 16,
#   "cmd": "tail -F /dev/null",
#   "container": {
#     "type": "MESOS"
#   },
#   "portDefinitions": [
#     {
#       "protocol": "tcp",
#       "port": 0
#     }
#   ],
#   "labels": {
#     "HAPROXY_GROUP": "external",
#     "HAPROXY_0_MODE": "http",
#     "HAPROXY_0_PORT": "6443",
#     "HAPROXY_0_SSL_CERT": "/etc/ssl/cert.pem",
#     "HAPROXY_0_BACKEND_SERVER_OPTIONS": "  timeout connect 10s\n  timeout client 86400s\n  timeout server 86400s\n  timeout tunnel 86400s\n  server nokia-cluster1 apiserver.nokia-cluster1.l4lb.thisdcos.directory:6443 ssl verify none\n"
#   }
# }
# EOF

# dcos kubernetes cluster kubeconfig \
#   --insecure-skip-tls-verify \
#   --context-name=nokia-cluster1 \
#   --cluster-name=nokia-cluster1 \
#   --apiserver-url=https://<marathon-lb-agent-ip>:6443

# echo "Adding kubectl-proxy marathon app..."

# dcos marathon app add kubectl-proxy.json

# sleep 15

# mlbTask="blah"
# kubectlIP="$(dcos node ssh --option StrictHostKeyChecking=no --option LogLevel=quiet --master-proxy --user=centos --mesos-id=$(dcos task | grep marathon-lb | awk '{print$6}') 'curl -s ifconfig.co')"

# dcos kubernetes cluster kubeconfig \
#     --insecure-skip-tls-verify \
#     --context-name=kubernetes-cluster1 \
#     --cluster-name=kubernetes-cluster1 \
#     --apiserver-url=https://${kubectlIP}:6443


echo -e "Adding edgelb and edgelb-pool repos"
dcos package repo add --index=0 edgelb https://downloads.mesosphere.com/edgelb/v1.3.1/assets/stub-universe-edgelb.json
dcos package repo add --index=0 edgelb-pool https://downloads.mesosphere.com/edgelb-pool/v1.3.1/assets/stub-universe-edgelb-pool.json

sleep 15

echo -e "Adding SA/secret/permissions for edgelb"
dcos security org service-accounts keypair edge-lb-private-key.pem edge-lb-public-key.pem
dcos security org service-accounts create -p edge-lb-public-key.pem -d "Edge-LB service account" edge-lb-principal
dcos security org service-accounts show edge-lb-principal
dcos security secrets create-sa-secret --strict edge-lb-private-key.pem edge-lb-principal dcos-edgelb/edge-lb-secret
dcos security org groups add_user superusers edge-lb-principal

echo -e "Writing-edgelb-options.json"
cat > edge-lb-options.json << EOF
{
    "service": {
        "secretName": "dcos-edgelb/edge-lb-secret",
        "principal": "edge-lb-principal",
        "mesosProtocol": "https"
    }
}
EOF

echo -e "Installing edgelb"
dcos package install --options=edge-lb-options.json edgelb --yes

sleep 30

echo -e "Writing edgelb pool options JSON file (edgelb.json)"
cat > edgelb.json << 'EOF'
{
    "apiVersion": "V2",
    "name": "edgelb-kubernetes-cluster-proxy",
    "count": 1,
    "autoCertificate": true,
    "haproxy": {
        "frontends": [{
                "bindPort": 6443,
                "protocol": "HTTPS",
                "certificates": [
                    "$AUTOCERT"
                ],
                "linkBackend": {
                    "defaultBackend": "kubernetes-cluster1"
                }
            }
        ],
        "backends": [{
                "name": "kubernetes-cluster1",
                "protocol": "HTTPS",
                "services": [{
                    "mesos": {
                        "frameworkName": "kubernetes-cluster1",
                        "taskNamePattern": "kube-control-plane"
                    },
                    "endpoint": {
                        "portName": "apiserver"
                    }
                }]
            }
        ],
        "stats": {
            "bindPort": 6090
        }
    }
}
EOF

echo -e "Creating edgelb pool"
dcos edgelb create edgelb.json

sleep 30

dcos edgelb status edgelb-kubernetes-cluster-proxy