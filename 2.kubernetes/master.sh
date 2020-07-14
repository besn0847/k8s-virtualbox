#!/bin/sh

MASTER_IP=$1
K8S_TOKEN=$2
NODE_NAME=$3

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
	
	CERT_VALUE=`ETCDCTL_API=3 etcdctl --user="vagrant:vagrant" --endpoints http://10.0.0.10:2379 get --print-value-only /kubernetes/certificate-key`
	DISCO_VALUE=`ETCDCTL_API=3 etcdctl --user="vagrant:vagrant" --endpoints http://10.0.0.10:2379 get --print-value-only /kubernetes/discovery-token-ca-cert-hash`

	kubeadm join services.k8s.local:6443 --token ${K8S_TOKEN} --discovery-token-ca-cert-hash ${DISCO_VALUE} --control-plane --certificate-key ${CERT_VALUE} --node-name ${NODE_NAME} --apiserver-advertise-address ${MASTER_IP}

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