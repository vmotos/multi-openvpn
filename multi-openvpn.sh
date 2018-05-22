#!/bin/bash
cp pass.txt ./multivpn
rm ./multivpn/*.ovpn

echo introduce numero de vpns concurrentes
read novpns

# Copia 3 ficheros ovpn adicionales por si algún peer falla
novpns=$((novpns + 3))

currentnovpns=0
while [ $novpns != $currentnovpns ]
do    
    randomvpn=$(ls *.ovpn | shuf -n 1)
    if [ ! -f ./multivpn/$randomvpn ]; then
        cp $randomvpn ./multivpn/ 
        echo "Copiado el fichero $randomvpn"
    fi
    currentnovpns=`ls -1 ./multivpn/*.ovpn 2>/dev/null | wc -l`
done

novpns=$((novpns - 3))

# levanta cada tunel con diferentes metricas
metric="20"
INT=$(ls /sys/class/net/ | grep -E '^eth|^en' | head -1)
GW=$(ip route show 0.0.0.0/0 dev $INT | cut -d\  -f3 | sort -u)

for file in $(ls ./multivpn/*.ovpn) 
    do
    echo "route-metric $metric" >> $file
    echo "route-nopull 1" >> $file
    echo "route 0.0.0.0 0.0.0.0 vpn_gateway $metric" >> $file
    metric=$((metric + 1))
done

cd multivpn

musthavetun=1
tries=1

for file in $(ls *.ovpn) 
do

    currenttun=$(ifconfig | grep tun | awk '{print $1}' | wc -l)
    echo -en "\nNúmero de túneles levantados: $currenttun\n"

    nohup openvpn $file 2>/dev/null &

    echo "Levantando interfaz de túnel"
    while [[ $currenttun -lt $musthavetun ]]
        do
            echo -en "."
            tries=$((tries + 1))
            sleep 1
            currenttun=$(ifconfig | grep tun | awk '{print $1}' | wc -l)
            if [ "$tries" = 30 ]
            then
                break
            fi
        done
    
    route del default gw $GW $INT 2>/dev/null
    route add default gw $GW $INT 2>/dev/null
    sleep 3
    if [ "$currenttun" = "$novpns" ]
    then 
        break    
    else
        musthavetun=$((musthavetun + 1))
        echo "ok!"
    fi
done

echo -e " todos los túneles levantados."
