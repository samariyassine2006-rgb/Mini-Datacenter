#!/bin/bash
# Teste le labo 03 : eBGP, tunnel WireGuard, accès au serveur web du site B.
P=clab-final
PASS=0
FAIL=0

check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "[OK]    $1"; PASS=$((PASS+1))
  else
    echo "[ECHEC] $1"; FAIL=$((FAIL+1))
  fi
}

echo "== Attente des sessions BGP (max 120 s) =="
for i in $(seq 1 60); do
  n=$(docker exec $P-risp vtysh -c "show bgp summary json" 2>/dev/null | grep -oE '"state": ?"Established"' | wc -l)
  [ "$n" -ge 2 ] && break
  sleep 2
done

echo "== Attente du bail DHCP de PC2 (max 60 s) =="
PC2=""
for i in $(seq 1 30); do
  PC2=$(docker exec $P-pc2 ip -4 -o addr show eth1 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
  [ -n "$PC2" ] && break
  sleep 2
done
echo "PC2 : ${PC2:-aucune adresse}"
sleep 3

echo "== Tests =="
check "BGP : 2 sessions établies sur R-ISP" '[ "$(docker exec $P-risp vtysh -c "show bgp summary json" 2>/dev/null | grep -oE "\"state\": ?\"Established\"" | wc -l)" -ge 2 ]'
check "Underlay : R1 joint R2 à travers l ISP (10.0.1.1 -> 10.0.2.2)" 'docker exec $P-r1 ping -c 2 -W 2 -I 10.0.1.1 10.0.2.2'
check "Tunnel : R1 joint R2 en 10.99.0.2" 'docker exec $P-r1 ping -c 2 -W 2 10.99.0.2'
check "WireGuard : handshake effectué" 'docker exec $P-r1 wg show wg0 latest-handshakes | grep -qE "[[:space:]][1-9][0-9]*$"'
check "Site A -> site B : PC1 joint PC2" 'docker exec $P-pc1 ping -c 2 -W 2 $PC2'
check "Site A -> site B : PC1 joint le serveur web" 'docker exec $P-pc1 ping -c 2 -W 2 10.2.20.10'
check "HTTP : PC1 récupère la page Nginx du site B" 'docker exec $P-pc1 wget -qO- -T 3 http://10.2.20.10 | grep -qi nginx'
check "Chemin : le trafic passe par le tunnel (10.99.0.2)" 'docker exec $P-pc1 traceroute -n -m 4 -w 1 -q 1 10.2.20.10 | grep -q 10.99.0.2'
check "Chemin : le trafic ne passe pas par l ISP" '! docker exec $P-pc1 traceroute -n -m 4 -w 1 -q 1 10.2.20.10 | grep -qE "10\.0\.1\.2|10\.0\.2\.1"'

echo
echo "== Détail du tunnel =="
docker exec $P-r1 wg show wg0 2>/dev/null
echo
echo "== Chemin PC1 -> web (le pare-feu bloque la fin du traceroute : normal) =="
docker exec $P-pc1 traceroute -n -m 4 -w 1 -q 1 10.2.20.10 2>/dev/null

echo
echo "Résultat : $PASS OK, $FAIL échec(s)"
[ "$FAIL" -eq 0 ]
