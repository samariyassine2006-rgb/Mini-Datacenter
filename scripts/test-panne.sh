#!/bin/bash
# Scénarios de panne du labo 03.
# Lancer sur un labo sain : ./scripts/deploy-final.sh && ./scripts/test-final.sh
#   Scénario 1 : coupure du lien R1 <-> ISP (sous-couche), puis rétablissement
#   Scénario 2 : coupure du tunnel WireGuard (wg0), puis rétablissement
P=clab-final
PASS=0
FAIL=0

ok() { echo "[OK]    $1"; PASS=$((PASS+1)); }
ko() { echo "[ECHEC] $1"; FAIL=$((FAIL+1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else ko "$1"; fi; }

bgp_up() { docker exec $P-risp vtysh -c "show bgp summary json" 2>/dev/null | grep -oE '"state": ?"Established"' | wc -l; }
web_ok() { docker exec $P-pc1 wget -qO- -T 3 http://10.2.20.10 2>/dev/null | grep -qi nginx; }

# wait_for "<commande>" <timeout> : affiche le temps écoulé, code 0 si la commande réussit
wait_for() {
  local cmd="$1" max="$2" start=$SECONDS
  while [ $((SECONDS-start)) -lt "$max" ]; do
    if eval "$cmd" >/dev/null 2>&1; then echo $((SECONDS-start)); return 0; fi
    sleep 1
  done
  echo "$max"; return 1
}

echo "=== État nominal ==="
check "BGP : 2 sessions établies" '[ "$(bgp_up)" -ge 2 ]'
check "PC1 atteint le serveur web du site B" web_ok
check "Les LAN des sites ne sont jamais visibles de l ISP" '! docker exec $P-risp vtysh -c "show ip route" | grep -qE "10\.[12]\.[12]0\."'

echo
echo "=== Scénario 1 : coupure du lien R1 <-> ISP (eth1 de R1) ==="
docker exec $P-r1 ip link set eth1 down
if t=$(wait_for '[ "$(bgp_up)" -le 1 ]' 30); then ok "BGP : la session R1-ISP tombe en ${t} s"; else ko "BGP : la session R1-ISP n est pas tombée en 30 s"; fi
check "Panne : PC1 n atteint plus le web du site B" '! web_ok'
check "Panne : les services locaux restent disponibles (DNS du site A)" 'docker exec $P-pc1 nslookup web.projet.local 10.1.20.10 | grep -q 10.2.20.10'
check "Panne : le site B reste intact (PC2 atteint son web local)" 'docker exec $P-pc2 wget -qO- -T 3 http://10.2.20.10 | grep -qi nginx'

echo "--- Rétablissement du lien"
docker exec $P-r1 ip link set eth1 up
T1=$SECONDS
if t=$(wait_for '[ "$(bgp_up)" -ge 2 ]' 30); then
  ok "BGP : sessions rétablies en ${t} s"
else
  echo "    (sessions toujours absentes après 30 s : relance de BGP sur R1)"
  docker exec $P-r1 vtysh -c "clear bgp *" >/dev/null 2>&1
  if t=$(wait_for '[ "$(bgp_up)" -ge 2 ]' 90); then ok "BGP : sessions rétablies après relance en $((SECONDS-T1)) s"; else ko "BGP : sessions non rétablies"; fi
fi
if t=$(wait_for 'docker exec $P-r1 ping -c 1 -W 1 -I 10.0.1.1 10.0.2.2' 30); then ok "Sous-couche : R1 rejoint R2 à travers l ISP"; else ko "Sous-couche non rétablie"; fi
if t=$(wait_for 'docker exec $P-r1 ping -c 1 -W 1 10.99.0.2 && web_ok' 90); then
  ok "Service complet rétabli (tunnel + web) $((SECONDS-T1)) s après la remise du lien"
else
  ko "Service non rétabli 90 s après la remise du lien"
fi

echo
echo "=== Scénario 2 : coupure du tunnel WireGuard (wg0 de R1) ==="
docker exec $P-r1 ip link set wg0 down
check "Tunnel coupé : PC1 n atteint pas le web (aucun repli en clair par l ISP)" '! web_ok'
check "Tunnel coupé : le BGP avec l ISP n est pas affecté" '[ "$(bgp_up)" -ge 2 ]'

echo "--- Rétablissement du tunnel"
docker exec $P-r1 ip link set wg0 up
docker exec $P-r1 ip route replace 10.2.0.0/16 dev wg0
T2=$SECONDS
if t=$(wait_for 'docker exec $P-r1 ping -c 1 -W 1 10.99.0.2 && web_ok' 60); then
  ok "Tunnel rétabli : PC1 atteint de nouveau le web ($((SECONDS-T2)) s)"
else
  ko "Tunnel non rétabli en 60 s"
fi

echo
echo "Résultat : $PASS OK, $FAIL échec(s)"
[ "$FAIL" -eq 0 ]
