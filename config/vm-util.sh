function makeHostAndBashEntries() {
    IFS=
    bash_entries=$(curl -sS https://raw.githubusercontent.com/sks336/vm-repo/master/config/bash_entries.txt)
    echo ${bash_entries} > /home/sachin/.bashrc
}

function makeBashEntries() {
    IFS=
    bash_entries=$(curl -sS https://raw.githubusercontent.com/sks336/vm-repo/master/config/bash_entries.txt)
    echo ${bash_entries} > /home/sachin/.bashrc
}

function refreshIPsFromConsul() {
echo '127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
255.255.255.255 broadcasthost

192.168.0.120   vm-0
192.168.109.11  vm-consul-vault-1
192.168.109.12  vm-consul-vault-2
192.168.109.13  vm-consul-vault-3
########################################

'>/etc/hosts

UPDATE_FROM_CONSUL="true"

while getopts o opts
do
    case "${opts}" in
        o) echo 'Option "-o" is chosen, NOT Going to update from Consul.....'
            UPDATE_FROM_CONSUL="false";;
    esac
done

if [ "$UPDATE_FROM_CONSUL" == "true" ]; then
        CONSUL_IP=192.168.109.11
        nodeJSON=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/nodes)
        nKeys=$(echo ${nodeJSON} | jq length)
        for ((i=0;i<nKeys;i++)); do
                host=$(echo ${nodeJSON} | jq -r .[$i].Node)
                ip=$(echo ${nodeJSON} | jq -r .[$i].Address)               
                echo -e "$ip   $host" >> /etc/hosts

        done

fi

echo 'Host Entry cleaned....'
cat /etc/hosts
}

function waitForIPAddressPopulation() {
    TIMEOUT=$1
    INTERVAL=$2
    ATTEMPT_COUNT=$(($TIMEOUT/$INTERVAL))
    echo "TIMEOUT=$TIMEOUT, INTERVAL=$INTERVAL, ATTEMPT_COUNT=$ATTEMPT_COUNT"
    i=1
        while [ "$i" -le "$ATTEMPT_COUNT" ]; do
            if [ "$ATTEMPT_COUNT" = "$i" ]; then
                echo 'Reached Time Out!!!!'
                ifconfig | grep -A 5 'eth1'
                return 1;
            fi
            IP_ADDR=$(ifconfig | grep -A 3 'eth1' | grep inet | grep netmask | awk '{print $2}')
            if [ ! -z $IP_ADDR ]; then
                echo 'IP Address is available and having value as ['${IP_ADDR}']'
                return 0;
            fi
            echo '['$i'] - IP not available yet, would be attempted again in '$INTERVAL' seconds'
            sleep $INTERVAL
            i=$(($i + 1))
        done
        
}

function registerToConsul() {  
    NODE_ID=$1
    NODE_TYPE=$2
    rm -rf ${HOME}/consul
    mkdir -p ${HOME}/consul
    cp -rf ${RESOURCES_DIR}/consul/* ${HOME}/consul
    IP_ADDR=$(ifconfig | grep -A 3 'eth1' | grep inet | grep netmask | awk '{print $2}')
    find ${HOME}/consul/service -type f | xargs sed -i  "s/<ID>/${NODE_ID}/g"
    find ${HOME}/consul/service -type f | xargs sed -i  "s/<NODE_ID>/${IP_ADDR}/g"
    find ${HOME}/consul/service -type f | xargs sed -i  "s/<NODE_TYPE>/${NODE_TYPE}/g"
    nohup consul agent -bind '{{ GetInterfaceIP "eth1" }}' -retry-join "vm-consul-vault-1" -config-dir ${HOME}/consul/service -data-dir /tmp/consul > ${HOME}/consul/consul.out &
    echo 'Services registered to Consul..'
}
