#!/usr/bin/env bash


function makeHostAndBashEntries() {
    IFS=
    host_entries=$(curl -sS https://raw.githubusercontent.com/sks336/vm-repo/master/config/host_entries.txt)
    echo ${host_entries} > /etc/hosts

    bash_entries=$(curl -sS https://raw.githubusercontent.com/sks336/vm-repo/master/config/bash_entries.txt)
    echo ${bash_entries} > /home/sachin/.bashrc
}

function pushIPInfoToConsul() {
    VM_PREFIX=$1
    NODE_ID=$2
    IP_ADDR=$(ifconfig | grep -A 1 'eth1' | tail -1 | awk '{print $2}')
    echo '>>>>> IP_ADDR='$IP_ADDR
    DATA_TO_PUSH={\"hostname\":\""${VM_PREFIX}-${NODE_ID}"\",\""ipaddress"\":\""${IP_ADDR}"\"}
    curl --request PUT --data $DATA_TO_PUSH http://192.168.109.11:8500/v1/kv/ipaddress/${VM_PREFIX}/${NODE_ID}
}
