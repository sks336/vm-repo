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
    CONSUL_IP=192.168.109.11
    IP_ADDR=$(ifconfig | grep -A 1 'eth1' | tail -1 | awk '{print $2}')
    DATA_TO_PUSH={\"hostname\":\""${VM_PREFIX}-${NODE_ID}"\",\""ipaddress"\":\""${IP_ADDR}"\"}
    echo 'Going to push the data to Consul'
    echo $DATA_TO_PUSH
    curl --request PUT --data $DATA_TO_PUSH http://${CONSUL_IP}:8500/v1/kv/ipaddress/${VM_PREFIX}/${NODE_ID}
}

function refreshIPsFromConsul() {
echo '127.0.0.1 localhost
127.0.0.1   vm-sachin
255.255.255.255 broadcasthost
::1             localhost

192.168.0.120   vm-0
192.168.109.11  vm-consul-vault-1
192.168.109.12  vm-consul-vault-2
192.168.109.13  vm-consul-vault-3

########################################

'>/etc/hosts

UPDATE_FROM_CONSUL="true"

while getopts c opts
do
    case "${opts}" in
        o) echo 'Option "-o" is chosen, NOT Going to update from Consul.....'
            UPDATE_FROM_CONSUL="false";;
    esac
done

if [ "$UPDATE_FROM_CONSUL" == "true" ]; then
        CONSUL_IP=192.168.109.11
        nKeys=$(curl -sS http://${CONSUL_IP}:8500/v1/kv/?keys | jq length)
        for ((i=0;i<nKeys;i++)); do
                key=$(curl -sS http://${CONSUL_IP}:8500/v1/kv/?keys | jq -r .[$i])
                json=$(curl -sS http://${CONSUL_IP}:8500/v1/kv/$key | jq -r .[0].Value | base64 --decode)
                host=$(echo $json | jq -r .hostname)
                ip=$(echo $json | jq -r .ipaddress)
                echo -e "$ip   $host" >> /private/etc/hosts
        done

fi

echo 'Host Entry cleaned....'
cat /etc/hosts

}
