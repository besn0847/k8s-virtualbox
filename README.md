# Kubernetes cluster in VirtualBox
This repository guides you n setting up a Kubernetes cluster with one VM acting as the proxy, 3 K8s masters and 2 workers.
## Pre-requisites
The following pre-requisites are necessary to have sufficient resources:
 - CPU : 6-core minimum but ideally 8+
 - RAM : 32 GB
 - DISK : 250 GB ideally SSD
 - Software : Vagrant 2.2.9 + Virtualbox 6.1.6

Each master is configured to use 3 GB of RAM, each worker is using 8 GB and the proxy VMs is using 1 GB. So makes 26 GB in total.
## Architecture
The kubernetes cluster is 3 masters for HA testing purposes and 2 workers for POD load-balancing testing purposes. 

The Services VM is used for 3 main workloads :
 1. Act as the proxy in front of the masters API servers (redirecting to port tcp/6443)
 2. Act as the DNS server for all the Kubernetes nodes
 3. Act as an etcd server to ease Kubernetes bootstrap by storing some security data such as token, certificates...

On the networking side, each node has 2 interfaces : the default NAT interface required by VirtualBox as well as a private one (10.0.0.0/24) for all nodes to communicate together.
## Bootstrapping
The initialization process is done in 3 steps :

 - Step 0 : Create the golden image "k8s-centos" with all the required software in it (directory : *0.centos-k8s*)
 - Step 1 : Bootstrap the Services VM to be used to initialize the Kub cluster and then act as the API proxy
 - Step 2 : Bootstrap the Kubernetes cluster
### Step 0 : Create the golden image
Just start the VM with vagrant, shut it down,package the box and then add it to the Vagrant boxes list.
```bash
cd 0.centos-k8s
vagrant up
vagrant halt
vagrant package --base k8s-centos --output k8s-centos.box
vagrant box add k8s-centos.box --name k8s-centos
```
Between UP and HALT, wait for the initialization and configuration to complete. This can be rather long as it downloads lots of stuff from Internet to ensure this is downloaded just once. The gloden image size after export is around 1 GB on disk.

### Step 1 : Kickoff the Services VM
Just start the Services VM and wait for the bootstrapping to complete. Please note that this required the Box configured in the previous step.
```bash
cd 1.services
vagrant up
```
This process usually takes 1 or 2 minutes.

### Step 2 : Bootstrap the Kubernetes cluster
Just go to the last directory, and kickoff teh Vagrant deployment. The process is as follows :

 - Master 1 is started and configured; the deployer waits until all PODs in kube-system are running (~3-4 minutes)
 - Master 2 is started and configured; same as above, the deployer waits for the master to be fully operational (~3-4 minutes)
 - Same for Master 3 (~3-4 minutes again)
 - The workers 1 and 2 are then started sequentially without waiting for one to complete and then the other; this is done in parallel
```bash
cd 2.kuberenetes
vagrant up
```
This process usually takes 10 to 15 minutes at the initialization must be done.

### Step 3 : Validate the Kubernetes is up and running
We connect to the first Kubernetes node, validate that all pods are running and finally we label the 2 worker nodes to act as workers. We do a final check that everything is ok.
```bash
cd 2.kuberenetes
vagrant ssh master1
[vagrant@master-1 ~]$ kubectl get pods -n kube-system
```
The expected result should be :
> TT

Now label the 2 worker nodes as workers and verify that all nodes are up & running
```bash
[vagrant@master-1 ~]$ kubectl label nodes worker-1 kubernetes.io/role=worker
[vagrant@master-1 ~]$ kubectl label nodes worker-1 kubernetes.io/role=worker
[vagrant@master-1 ~]$ kubectl get nodes
```
The expected result should be :
|NAME|READY|STATUS|RESTARTS|AGE|
|-|-|-|-|-|
|calico-kube-controllers-76d4774d89-zwnm9|1/1|Running|0|17m|
|calico-node-24t8c|1/1|Running|0|17m|
|calico-node-j9tzx|1/1|Running|0|13m|
|calico-node-mxjh6|1/1|Running|0|5m28s|
|calico-node-r7zhq|1/1|Running|0|6m59s|
|calico-node-rntpv|1/1|Running|0|10m|


### Step 3 : Validate the Kubernetes is up and running
Now simply stop the K8s cluster and then the Services VM (in that order since the proxy is used to communicate to the API servers.
```bash
[vagrant@master-1 ~]$ exit
vagrant halt
cd ../1.services
vagrant halt
```
Your Kubernetes cluster can now be restarted anytime you want. Just don't forget to start the Services VM first.