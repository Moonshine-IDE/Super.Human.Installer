#!/bin/bash

S=$1;
T=$2;
if [ -z "$S" ]
then
    echo "A role is not specified, Skipping addition of branch from Github Repo $T"
else
    echo "A role is specified, Adding role $S from Github Repo $T"
#    sudo rm -rf /temp
#    sudo mkdir -p /temp
#    sudo git clone -b master $T.git /temp
#    mkdir /vagrant/$S
#    cp -r /temp/conf/* /vagrant/$S
#	cat /vagrant/hosts >> /etc/hosts
fi