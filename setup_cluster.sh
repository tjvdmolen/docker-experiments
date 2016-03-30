#!/bin/bash

#Azure settings
REGION="West Europe"
SERVICE=k8s-test
#USERPROFILE
VM_SIZE="Small"
CERT="$HOME/.ssh/id_rsa.pub"
CLUSTER_NAME=k8s-test
USER=core
MASTERS=1
WORKERS=2
TOTAL_NODES=$(($MASTERS + $WORKERS))
SSH_PORT_START=2022
#Version of CoreOS to use, see: https://coreos.com/os/docs/latest/booting-on-azure.html
IMAGE="2b171e93f07c4903bcad35bda10acf22__CoreOS-Beta-991.2.0"


echo Fetching token
TOKEN=$(curl -s -w "\n" "https://discovery.etcd.io/new?size=$TOTAL_NODES")
echo "$TOKEN" > .discovery_token
echo "Token: $TOKEN"
#escaping token for use with sed replace
TOKEN=$(echo "$TOKEN"|sed -e 's/[\/&]/\\&/g')
echo "Building template"

echo Creating service if it doesnt exist yet
azure service create --location="$REGION" $SERVICE 

SSH_PORT=$SSH_PORT_START
i=0
#Role is used for the metadata for fleet
ROLE=master
while [ $i -lt $MASTERS ]; do
	HOSTNAME=$CLUSTER_NAME-$ROLE-$i
	sed -e "s/<token>/$TOKEN/g" -e "s/<role>/$ROLE/g" cloud-config-template.yaml > .cloud-config.yaml
	echo "Creating machine $HOSTNAME"
	
	azure vm create --custom-data=.cloud-config.yaml --vm-size="$VM_SIZE" --ssh="$SSH_PORT" --ssh-cert="$CERT" --no-ssh-password --vm-name="$HOSTNAME" --location="$REGION" --connect="$SERVICE" $IMAGE $USER
	
	let SSH_PORT=SSH_PORT+1
	let i=i+1 
done
i=0
#Role is used for the metadata for fleet
ROLE=worker
while [ $i -lt $WORKERS ]; do
	HOSTNAME=$CLUSTER_NAME-$ROLE-$i
	sed -e "s/<token>/$TOKEN/g" -e "s/<role>/$ROLE/g" cloud-config-template.yaml > .cloud-config.yaml
	echo "Creating machine $HOSTNAME"
	
	azure vm create --custom-data=.cloud-config.yaml --vm-size="$VM_SIZE" --ssh="$SSH_PORT" --ssh-cert="$CERT" --no-ssh-password --vm-name="$HOSTNAME" --location="$REGION" --connect="$SERVICE" $IMAGE $USER
	
	let SSH_PORT=SSH_PORT+1
	let i=i+1 
done