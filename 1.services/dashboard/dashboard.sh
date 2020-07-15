#!/bin/sh

# Create service account & role binding
kubectl apply -f dashboard-adminuser.yml
kubectl apply -f admin-role-binding.yml

# Install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml

# Get token to be used for authentication
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | grep 'token:'

echo "Now :"
echo "	1/ Start the proxy server on this VM : kubectl proxy"
echo "	2/ Use SSH tunneling on port 8010 to connect to 127.0.0.1:8001"
echo "	3/ Connect from your desktop to http://127.0.0.1:8010/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"