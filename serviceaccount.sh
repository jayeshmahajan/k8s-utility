#!/bin/bash
#
# run in context of account
# ex. infra
# ./deployer.sh ClusterName CustomUser My_Env
_clustername=$1
_username_=$2
_env_=$3
export ROLE="cluster-admin"
export NS="kube-system"
echo "create service account ${_username_} for env ${_env_}"
kubectl create sa $_username_ -n $NS
echo "Bind SA ${_username_} with ClusterRole ${ROLE} for environment ${_env_}"
kubectl create clusterrolebinding $_username_ \
 --serviceaccount=$NS:$_username_ \
 --clusterrole=${ROLE} 
SECRET_NAME=$(kubectl get sa $_username_ -n $NS -o json | jq -r .secrets[0].name)
TOKEN=$(kubectl get secrets $SECRET_NAME -n $NS -o json | jq -r .data.token | base64 -D)
CA=$(kubectl get secrets $SECRET_NAME -n $NS -o json | jq -r '.data | .["ca.crt"]')
SERVER=$(aws eks describe-cluster --name $_clustername | jq -r .cluster.endpoint)
cat <<-EOF > $_username_-$_env_.yaml
apiVersion: v1
kind: Config
users:
- name: $_username_
  user:
    token: $TOKEN
clusters:
- cluster:
    certificate-authority-data: $CA
    server: $SERVER
  name: $_username_
contexts:
- context:
    cluster: $_username_
    user: $_username_
  name: $_username_
current-context: $_username_
EOF
echo "Created kubeconfig $_username_-$_env_.yaml"