#!bin/sh

# Script de iptables.

# Variables ip.

LAN_IP='192.168.101.254'
WAN_IP='10.3.4.171'
DMZ_IP='172.20.101.254'

# Variables interface.

LAN_IF='ens9'
WAN_IF='ens8'
DMZ_IF='ens3'

# Iniciar el FW.

inicia() {

# Activar enrutado.

echo 1 > /proc/sys/net/ipv4/ip_forward

# Borrar reglas.

iptables -F

# Reglas por defecto.

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Reglas de acceso SSH.

# LAN

iptables -A INPUT -s $LAN_IP -i $LAN_IF -p tcp --dport 2222 -j ACCEPT

## iptables -A OUTPUT -d $LAN_IP -o $LAN_IF -p tcp --sport 2222 -j ACCEPT

# WAN

iptables -A INPUT -s $WAN_IP -i $WAN_IF -p tcp --dport 2222 -j ACCEPT

## iptables -A OUTPUT -d $WAN_IP -o $WAN_IF -p tcp --sport 2222 -j ACCEPT

# DMZ.

iptables -A INPUT -s $DMZ_IP -i $DMZ_IF -p tcp --dport 2222 -j ACCEPT

## iptables -A OUTPUT -d $DMZ_IP -o $DMZ_IF -p tcp --sport 2222 -j ACCEPT

# Contestación SSH.

iptables -A OUTPUT -p tcp --sport 2222 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Reglas del servicio DHCPD.

iptables -A INPUT -i $LAN_IF -p udp --dport 68 --sport 67 -j ACCEPT
iptables -A OUTPUT -o $LAN_IF -p udp --sport 67 --dport 68 -j ACCEPT

iptables -A INPUT -i $DMZ_IF -p udp --dport 68 --sport 67 -j ACCEPT
iptables -A OUTPUT -o $DMZ_IF -p udp --sport 67 --dport 68 -j ACCEPT

# Contestación DHCPD.

## iptables -A OUTPUT

# Reglas del cliente DHCP.

iptables -A OUTPUT -o $WAN_IF -p udp --dport 67 --sport 68 -j ACCEPT
iptables -A INPUT -i $WAN_IF -p udp --sport 68 --dport 67 -j ACCEPT

# SSH de LAN a DMZ.

iptables -A FORWARD -s $LAN_IP -d $DMZ_IP -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -d $LAN_IP -s $DMZ_IP -p tcp --sport 22 -j ACCEPT

# DNS de LAN a DMZ.

iptables -A FORWARD -s $LAN_IP -d $DMZ_IP -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -d $LAN_IP -s $DMZ_IP -p udp --sport 53 -j ACCEPT

# http a la DMZ.

iptables -A FORWARD -d $DMZ_IP -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s $DMZ_IP -p tcp --sport 80 -j ACCEPT

# Desde DMZ a servidor web en WAN.

iptables -A FORWARD -i $DMZ_IF -s $DMZ_IP -o $WAN_IF -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $WAN_IF -d $DMZ_IP -o $WAN_IF -p tcp --sport 80 -j ACCEPT

# https a la DMZ.

iptables -A FORWARD -d $DMZ_IP -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s $DMZ_IP -p tcp --sport 443 -j ACCEPT

# PING.

iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT
iptables -A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT

# Acceso desde la WAN al servidor web.

iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 80 -j DNAT --to 172.20.101.22

# Salida a repositorios de servidores de DMZ.

iptables -t nat -A POSTROUTING -s $DMZ_IP -o $WAN_IF -p tcp --dport 80 -j SNAT --to 10.3.4.171

# SSH a DMZ.

iptables -t nat -A PREROUTING -i $WAN_IF -d 10.3.4.171 -p tcp --dport 2222 -j DNAT --to 172.20.101.22

# Acceso desde Firewall al servidor DNS.

iptables -A OUTPUT -o $DMZ_IF -s 172.20.101.254 -p udp --dport 53 -d 172.20.101.22 -j ACCEPT
iptables -A INPUT -i $DMZ_IF -d 172.20.101.254 -p udp --sport 53 -s 172.20.101.22 -j ACCEPT

# Acceso desde wan al servidor DNS.

iptables -t nat -A PREROUTING -i $WAN_IF -d 10.3.4.171 -p udp --dport 53 -j DNAT --to 172.20.101.22

}

#función para parar el FW.

para() {

# Limpieza tabla.

iptables -F

# Reglas generales.

iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

}


# Operación principal del script
# Para comprobar que eres root averiguamos si el id es 0
# [ $(id -u) -eq 0 ]

# Comprobamos los parámetros y seleccionamos la opción correcta.


if [ $# -ne 1 ]
        then
                echo "Parámetros incorrectos. Escriba start o stop."
                exit 23
fi

case $1 in
        'start') inicia;;
        'stop') para;;
        *) echo "Parámetro incorrecto.";exit 24;;
esac

exit 0
# asir-files
