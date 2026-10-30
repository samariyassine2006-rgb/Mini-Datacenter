#!/bin/bash
# Teste le labo 01 (OSPF).
# Lancer après : sudo containerlab deploy -t labs/01-ospf/topologie.clab.yml
P=clab-ospf-lab

echo "== Attente de l'adjacence OSPF (max 90 s) =="
for i in $(seq 1 45); do
  if docker exec $P-r1 vtysh -c "show ip ospf neighbor" 2>/dev/null | grep -q "Full"; then
    echo "Adjacence Full après environ $((i*2)) s"
    break
  fi
  sleep 2
done
sleep 3

echo "== Voisins OSPF de r1 =="
docker exec $P-r1 vtysh -c "show ip ospf neighbor" 2>/dev/null
echo "== Routes OSPF de r1 =="
docker exec $P-r1 vtysh -c "show ip route ospf" 2>/dev/null
echo "== Ping PC1 -> PC2 =="
docker exec $P-pc1 ping -c 3 10.2.10.100 && echo "OK" || echo "ECHEC"
