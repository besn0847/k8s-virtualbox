#!/bin/sh

cd bootstrap

# Configure HAproxy service
sudo yum install -y haproxy

sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg

sudo setsebool -P haproxy_connect_any 1
sudo systemctl enable haproxy
sudo systemctl start haproxy
sudo systemctl status haproxy

# Configure DNS service
sudo yum -y install bind bind-utils
sudo cp named.conf /etc/named.conf
sudo cp named.conf.local /etc/named/
sudo mkdir /etc/named/zones
sudo cp db* /etc/named/zones

sudo systemctl enable named
sudo systemctl start named
sudo systemctl status named

nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
nmcli con mod "System eth1" ipv4.dns "10.0.0.10 8.8.8.8 8.8.4.4"
nmcli con mod "System eth1" ipv4.dns-search "k8s.local, cluster.k8s.local"
nmcli con down "System eth0"
nmcli con down "System eth1"
nmcli con up "System eth0"
nmcli con up "System eth1"

# Set-up the etcd to be used to publish value-pair
sed -i 's/localhost/10.0.0.10/g' /etc/etcd/etcd.conf

systemctl enable etcd
systemctl start etcd

etcdctl --endpoints http://10.0.0.10:2379 user add vagrant:vagrant
etcdctl --endpoints http://10.0.0.10:2379 role add kubernetes
etcdctl --endpoints http://10.0.0.10:2379 role grant kubernetes -path '/kubernetes/*' --readwrite
etcdctl --endpoints http://10.0.0.10:2379 user grant --roles kubernetes vagrant

