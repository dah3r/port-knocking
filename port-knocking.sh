#! /bin/bash
IPT=/bin/iptables
INT=enp0s8 #Interfaz hacia red interna
EXT=enp0s3 #Interfaz hacia internet
SER=       #Interfaz hacia red de servidores



#DEFAULT RULES

$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT 
$IPT -P FORWARD ACCEPT

#Reset former rules to avoid conflicts
$IPT -F
$IPT -X
$IPT -F -t nat
$IPT -F -t mangle

### Creamos las cadenas que usaremos
$IPT -N KNOCKING
$IPT -N GATE1
$IPT -N GATE2
$IPT -N GATE3
$IPT -N PASSED

#Accept loopback established and/or related connections
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Todo lo que no hayamos filtrado lo metemos en KNOCKING
$IPT -A INPUT -j KNOCKING

#Primer knock
$IPT -A GATE1 -p tcp --dport 1111 -m recent --name AUTH1 --set -j DROP

#Dropeamos el resto
$IPT -A GATE1 -j DROP

#Borramos la flag anterior
$IPT -A GATE2 -m recent --name AUTH1 --remove

#Segundo knock
$IPT -A GATE2 -p tcp --dport 2222 -m recent --name AUTH2 --set -j DROP

#Si no ha hecho knock lo dropeamos (GATE1 ya configurada, esto es por si se hace knock dos veces al primer puerto para que no de problemas)
$IPT -A GATE2 -j GATE1

#Borramos la flag anterior
$IPT -A GATE3 -m recent --name AUTH2 --remove

#Tercer knock
$IPT -A GATE3 -p tcp --dport 3333 -m recent --name AUTH3 --set -j DROP

#Lo mismo que antes
$IPT -A GATE3 -j GATE1

#Limpiamos flag
$IPT -A PASSED -m recent --name AUTH3 --remove

#Aceptamos los ssh (port 22) que estén en la cadena PASSED 
$IPT -A PASSED -p tcp --dport 22 -j ACCEPT

#Si no coincide con nada lo volvemos a mandar a la primera puerta (lo mismo que antes)
$IPT -A PASSED -j GATE1


##### Configuración cadena KNOCKING 

#Damos 30s para que el cliente se conecte al daemon tras el tercer knock
$IPT -A KNOCKING -m recent --rcheck --seconds 30 --name AUTH3 -j PASSED

#Ponemos límite de tiempo entres los otros knocks también
$IPT -A KNOCKING -m recent --rcheck --seconds 10 --name AUTH2 -j GATE3
$IPT -A KNOCKING -m recent --rcheck --seconds 10 --name AUTH1 -j GATE2

#Mandamos a gate1
$IPT -A KNOCKING -j GATE1




echo 1 > /proc/sys/net/ipv4/ip_forward
