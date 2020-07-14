#!/bin/sh

MASTER_IP=$1
K8S_TOKEN=$2
K8S_VERSION=$3
NODE_NAME=$4

echo "MASTER_IP : ${MASTER_IP}"
echo "K8S_TOKEN : ${K8S_TOKEN}"
echo "K8S_VERSION : ${K8S_VERSION}"
echo "NODE_NAME : ${NODE_NAME}"
 
# Set-up DNS and routing
nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
nmcli con mod "System eth1" ipv4.dns "10.0.0.10 8.8.8.8 8.8.4.4"
nmcli con mod "System eth1" ipv4.dns-search "k8s.local, cluster.k8s.local"
nmcli con down "System eth0" && nmcli con up "System eth0"
nmcli con down "System eth1" && nmcli con up "System eth1"

# Clean /etc/hosts
sed -i '/master-/d' /etc/hosts
cat >> /etc/hosts << EOF

${MASTER_IP}	${NODE_NAME}
EOF
 
# Eanble and start Docker engine & kubelet service
sudo systemctl enable docker
sudo systemctl start docker

systemctl enable kubelet.service
systemctl start kubelet.service

# Set-up iptables
cat  >> /etc/sysctl.conf << EOF

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables

# Bootstrap Kubernetes cluster
cat >> /etc/profile << EOF

K8S_TOKEN=$1; export K8S_TOKEN
EOF

if [ ! -f /.bootstrap ]
then
	echo 1 > /.bootstrap
	
	kubeadm init --control-plane-endpoint services.k8s.local:6443 --apiserver-advertise-address ${MASTER_IP} --upload-certs --kubernetes-version ${K8S_VERSION} --node-name ${NODE_NAME} --service-dns-domain cluster.k8s.local --token ${K8S_TOKEN} --pod-network-cidr 192.168.0.0/16 > /tmp/kub.init 2>&1

	DISCO_VALUE=`grep -oP 'discovery-token-ca-cert-hash ([a-zA-Z:0-9]*) $' /tmp/kub.init | awk '{print $2}' -`
	CERT_VALUE=`grep -oP 'certificate-key ([a-zA-Z:0-9]+)' /tmp/kub.init | grep -v gives | awk '{print $2}' -`

	ETCDCTL_API=3 etcdctl --user="vagrant:vagrant" --endpoints http://10.0.0.10:2379 put /kubernetes/discovery-token-ca-cert-hash $DISCO_VALUE
	ETCDCTL_API=3 etcdctl --user="vagrant:vagrant" --endpoints http://10.0.0.10:2379 put /kubernetes/certificate-key $CERT_VALUE

	KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml

	sudo mkdir -p /home/vagrant/.kube
	sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
	sudo chown vagrant:vagrant /home/vagrant/.kube/config

	KUBECONFIG=/etc/kubernetes/admin.conf; export KUBECONFIG
	sleep 15
	while ([ `kubectl get pods -n kube-system --field-selector status.phase!=Running | wc -l` -gt 0  ])
	do
		kubectl get pods -n kube-system --field-selector status.phase!=Running
		sleep 15
		echo ""
	done

fi

# Once all worker are up & running
# kubectl label nodes worker-1 kubernetes.io/role=worker
# kubectl label nodes worker-2 kubernetes.io/role=worker
