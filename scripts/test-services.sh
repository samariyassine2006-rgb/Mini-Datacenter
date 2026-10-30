#!/bin/bash
# Teste les services (DHCP, DNS), le NAT et le pare-feu du labo 03.
# Lancer après : ./scripts/deploy-final.sh
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

echo "== Attente des baux DHCP (max 60 s) =="
for i in $(seq 1 30); do
  a=$(docker exec $P-pc1 ip -4 -o addr show eth1 2>/dev/null | grep -c 'inet 10\.1\.10\.')
  b=$(docker exec $P-pc2 ip -4 -o addr show eth1 2>/dev/null | grep -c 'inet 10\.2\.10\.')
  [ "$a" -ge 1 ] && [ "$b" -ge 1 ] && break
  sleep 2
done
sleep 3

echo "== DHCP =="
check "PC1 reçoit une adresse du pool 10.1.10.100-199" 'docker exec $P-pc1 ip -4 -o addr show eth1 | grep -qE "inet 10\.1\.10\.1[0-9][0-9]/"'
check "PC1 sort par la passerelle 10.1.10.1 (route vers le web)" 'docker exec $P-pc1 ip route get 10.2.20.10 | grep -q "via 10.1.10.1"'
check "PC2 reçoit une adresse du pool 10.2.10.100-199" 'docker exec $P-pc2 ip -4 -o addr show eth1 | grep -qE "inet 10\.2\.10\.1[0-9][0-9]/"'
check "PC2 sort par la passerelle 10.2.10.1 (route vers le DNS)" 'docker exec $P-pc2 ip route get 10.1.20.10 | grep -q "via 10.2.10.1"'

echo "== DNS =="
check "PC1 résout web.projet.local (site A)" 'docker exec $P-pc1 nslookup web.projet.local 10.1.20.10 | grep -q 10.2.20.10'
check "PC2 résout web.projet.local à travers le tunnel (site B)" 'docker exec $P-pc2 nslookup web.projet.local 10.1.20.10 | grep -q 10.2.20.10'
check "PC1 atteint le web par son nom (DNS fourni par DHCP)" 'docker exec $P-pc1 wget -qO- -T 3 http://web.projet.local | grep -qi nginx'

echo "== NAT =="
check "NAT : PC1 joint l ISP (10.0.2.1) grâce au masquerade" 'docker exec $P-pc1 ping -c 2 -W 2 10.0.2.1'
check "NAT : le compteur masquerade de R1 a augmenté" 'docker exec $P-r1 nft list chain ip nat postrouting | grep -qE "counter packets [1-9]"'
check "Pas de NAT entre sites : le web voit l IP réelle de PC1" 'docker logs $P-web 2>&1 | tail -n 10 | grep -qE "^10\.1\.10\."'

echo "== Pare-feu =="
check "R1 : politique d entrée par défaut = refus" 'docker exec $P-r1 nft list chain inet filter input | grep -q "policy drop"'
check "R2 : politique de transit par défaut = refus" 'docker exec $P-r2 nft list chain inet filter forward | grep -q "policy drop"'
drops() { docker exec $P-r2 nft list chain inet filter input | grep -oE "counter packets [0-9]+ bytes [0-9]+ drop" | grep -oE "packets [0-9]+" | grep -oE "[0-9]+"; }
BEFORE=$(drops)
docker exec $P-pc1 wget -qO- -T 2 http://10.99.0.2:179 >/dev/null 2>&1
AFTER=$(drops)
if [ -n "$BEFORE" ] && [ -n "$AFTER" ] && [ "$AFTER" -gt "$BEFORE" ]; then
  echo "[OK]    R2 : un accès au port 179 via le tunnel est bloqué (drops $BEFORE -> $AFTER)"; PASS=$((PASS+1))
else
  echo "[ECHEC] R2 : un accès au port 179 via le tunnel est bloqué (drops $BEFORE -> $AFTER)"; FAIL=$((FAIL+1))
fi
check "Isolation : le serveur web ne peut pas initier vers le site A" '! docker exec $P-web ping -c 2 -W 2 10.1.20.10'
check "BGP toujours établi malgré le pare-feu" '[ "$(docker exec $P-risp vtysh -c "show bgp summary json" 2>/dev/null | grep -oE "\"state\": ?\"Established\"" | wc -l)" -ge 2 ]'

echo
echo "== Règles actives sur R1 =="
docker exec $P-r1 nft list ruleset 2>/dev/null
echo
echo "Résultat : $PASS OK, $FAIL échec(s)"
[ "$FAIL" -eq 0 ]
