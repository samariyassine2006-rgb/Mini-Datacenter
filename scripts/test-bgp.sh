#!/bin/bash
# Teste le labo 02 (eBGP).
# Lancer après : sudo containerlab deploy -t labs/02-bgp/topologie.clab.yml
P=clab-bgp-lab

echo "== Attente des sessions BGP (max 120 s) =="
OK=0
for i in $(seq 1 60); do
  n=$(docker exec $P-risp vtysh -c "show bgp summary json" 2>/dev/null | grep -oE '"state": ?"Established"' | wc -l)
  if [ "$n" -ge 2 ]; then
    echo "2 sessions établies après environ $((i*2)) s"
    OK=1
    break
  fi
  sleep 2
done
[ "$OK" -eq 0 ] && echo "ATTENTION : sessions BGP non établies après 120 s"
sleep 5

echo "== R-ISP : sessions BGP =="
docker exec $P-risp vtysh -c "show bgp summary" 2>/dev/null
echo "== R1 : table BGP =="
docker exec $P-r1 vtysh -c "show ip bgp" 2>/dev/null
echo "== R2 : table BGP =="
docker exec $P-r2 vtysh -c "show ip bgp" 2>/dev/null

echo "== Extrémités du tunnel WireGuard à travers l'ISP =="
docker exec $P-r1 ping -c 3 -I 10.0.1.1 10.0.2.2 && echo "R1 -> R2 : OK" || echo "R1 -> R2 : ECHEC"
docker exec $P-r2 ping -c 3 -I 10.0.2.2 10.0.1.1 && echo "R2 -> R1 : OK" || echo "R2 -> R1 : ECHEC"
