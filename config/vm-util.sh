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
CONSUL_IP=192.168.109.11
HOST_FILE=/etc/hosts
if [ "$(uname -s)" != "Linux" ]; then
	HOST_FILE=/private/etc/hosts
fi
echo 'HOST_FILE='${HOST_FILE}
nServices=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/services | jq keys | jq length)
entriesFromConsul=''
for ((i=0;i<nServices;i++)); do
        serviceName=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/services | jq keys | jq -r .[$i])
        if [ "${serviceName}" == "consul" ]; then
        	echo 'Ignore consul service entries' > /dev/null 2>&1
        else
        	serviceJSON=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/service/${serviceName})
        	nMachines=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/service/${serviceName} | jq length)
        	for ((j=0;j<nMachines;j++)); do
        	machineJSON=$(curl -sS http://${CONSUL_IP}:8500/v1/catalog/service/${serviceName} | jq .[$j])
        	ip=$(echo $machineJSON | jq -r .ServiceAddress)
        	vmName="vm-"$(echo $machineJSON | jq -r .ServiceID)
        	hostEntry="${ip}"$'\t'"${vmName}"
        	entriesFromConsul=${entriesFromConsul}${hostEntry}$'\n'
	    	done
        fi
done

echo '127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
255.255.255.255 broadcasthost
127.0.0.1       vm-sachin
192.168.0.120   vm-0
192.168.109.11  vm-consul-vault-1
192.168.109.12  vm-consul-vault-2
192.168.109.13  vm-consul-vault-3
########################################
'>${HOST_FILE}

echo "$entriesFromConsul" >> ${HOST_FILE}
echo 'Host Entry cleaned....'
cat ${HOST_FILE}
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
                echo 'IP Address is available and having value as ['${IP_ADDR}'] with HostName as ['$(hostname -f)']'
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
    CONSUL_IP=192.168.109.11
    IP_ADDR=$(ifconfig | grep -A 3 'eth1' | grep inet | grep netmask | awk '{print $2}')
    find ${HOME}/resources/config/consul/service -type f | xargs sed -i  "s/<ID>/${NODE_ID}/g"
    find ${HOME}/resources/config/consul/service -type f | xargs sed -i  "s/<NODE_ID>/${IP_ADDR}/g"
    find ${HOME}/resources/config/consul/service -type f | xargs sed -i  "s/<NODE_TYPE>/${NODE_TYPE}/g"
    nohup consul agent -node ${IP_ADDR} -bind '{{ GetInterfaceIP "eth1" }}' -retry-join "${CONSUL_IP}" -config-dir ${HOME}/resources/config/consul/service -data-dir /tmp/consul --enable-local-script-checks=true > ${HOME}/consul.out &
    echo 'Services registered to Consul..'
}
