#!/bin/bash
# Déploie le labo 03 de bout en bout : images, topologie, convergence BGP, tunnel WireGuard.
set -e
cd "$(dirname "$0")/.."
P=clab-final

echo "== Construction des images (rapide si déjà construites) =="
docker build -q -t frr-wg:latest labs/03-final
docker build -q -t lab-tools:latest -f labs/03-final/Dockerfile.tools labs/03-final

echo "== Déploiement de la topologie =="
(cd labs/03-final && sudo containerlab deploy -t topologie.clab.yml --reconfigure)

echo "== Attente de la sous-couche : R1 et R2 doivent se joindre à travers l'ISP (max 120 s) =="
UP=0
for i in $(seq 1 60); do
  if docker exec $P-r1 ping -c 1 -W 1 -I 10.0.1.1 10.0.2.2 >/dev/null 2>&1 && \
     docker exec $P-r2 ping -c 1 -W 1 -I 10.0.2.2 10.0.1.1 >/dev/null 2>&1; then
    UP=1
    echo "Sous-couche opérationnelle après environ $((i*2)) s"
    break
  fi
  sleep 2
done
if [ "$UP" -eq 0 ]; then
  echo "ERREUR : R1 et R2 ne se joignent pas à travers l'ISP. Diagnostic :"
  docker exec $P-risp vtysh -c "show bgp summary" 2>/dev/null
  echo "--- route de R1 vers 10.0.2.0/30"; docker exec $P-r1 vtysh -c "show ip route 10.0.2.0/30" 2>/dev/null
  echo "--- route de R2 vers 10.0.1.0/30"; docker exec $P-r2 vtysh -c "show ip route 10.0.1.0/30" 2>/dev/null
  exit 1
fi

echo "== Configuration du tunnel WireGuard =="
./scripts/setup-wireguard.sh

echo "== Attente du handshake WireGuard (max 30 s) =="
for i in $(seq 1 15); do
  docker exec $P-r1 ping -c 1 -W 1 10.99.0.2 >/dev/null 2>&1 || true
  if docker exec $P-r1 wg show wg0 latest-handshakes | grep -qE "[[:space:]][1-9][0-9]*$"; then
    echo "Handshake effectué"
    break
  fi
  sleep 2
done

echo "Labo prêt. Lancer : ./scripts/test-final.sh puis ./scripts/test-services.sh"
