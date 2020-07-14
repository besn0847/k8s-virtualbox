#!/bin/sh

# Update vagrant user pub key
mv authorized_keys /home/vagrant/.ssh/authorized_keys
chown vagrant.vagrant /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys

# Turn off swap
sudo swapoff -a
sudo sed -i 's/^\/swapfile/#&/' /etc/fstab

# Disable SE Linux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# Install Docker engine
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io

# Install Kubernetes packages
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo yum install -y kubelet kubeadm kubectl

# Download Kubernetes images once for all
sudo systemctl enable docker
sudo systemctl start docker

kubeadm config images pull

# Turn off auto start-up 
sudo systemctl stop docker
sudo systemctl disable docker
systemctl stop kubelet.service
systemctl disable kubelet.service

# Install etcd to be used to share certificates
yum install -y etcd