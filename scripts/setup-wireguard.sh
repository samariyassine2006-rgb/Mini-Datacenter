#!/bin/bash
# Configure le tunnel WireGuard entre R1 et R2 (labo 03).
# Les clés sont générées à chaque déploiement : aucun secret dans le dépôt.
set -e
P=clab-final

for n in r1 r2; do
  docker exec $P-$n sh -c 'mkdir -p /etc/wireguard && umask 077 && wg genkey > /etc/wireguard/privatekey && wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey'
done
R1_PUB=$(docker exec $P-r1 cat /etc/wireguard/publickey)
R2_PUB=$(docker exec $P-r2 cat /etc/wireguard/publickey)

# R1 : tunnel vers R2 (endpoint 10.0.2.2), site B joignable via wg0
docker exec $P-r1 sh -c "
ip link add wg0 type wireguard &&
ip addr add 10.99.0.1/30 dev wg0 &&
wg set wg0 listen-port 51820 private-key /etc/wireguard/privatekey peer $R2_PUB endpoint 10.0.2.2:51820 allowed-ips 10.99.0.2/32,10.2.0.0/16 &&
ip link set wg0 up &&
ip route add 10.2.0.0/16 dev wg0"

# R2 : tunnel vers R1 (endpoint 10.0.1.1), site A joignable via wg0
docker exec $P-r2 sh -c "
ip link add wg0 type wireguard &&
ip addr add 10.99.0.2/30 dev wg0 &&
wg set wg0 listen-port 51820 private-key /etc/wireguard/privatekey peer $R1_PUB endpoint 10.0.1.1:51820 allowed-ips 10.99.0.1/32,10.1.0.0/16 &&
ip link set wg0 up &&
ip route add 10.1.0.0/16 dev wg0"

echo "Tunnel WireGuard configuré (R1 10.99.0.1 <-> R2 10.99.0.2)."
