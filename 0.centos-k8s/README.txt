0/ Create a K8S CentOS box in Virtual box with correct set-up

1/ Export the box 
	vagrant package --base k8s-centos --output k8s-centos.box

2/ Import the new box into vagrant
	vagrant box add k8s-centos.box --name k8s-centos
 
*Option* : Remove the box 
	vagrant box remove k8s-centos
