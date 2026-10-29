#!/bin/bash
# Déploie le labo 03 de bout en bout : image, topologie, tunnel WireGuard.
set -e
cd "$(dirname "$0")/.."

if ! docker image inspect frr-wg:latest >/dev/null 2>&1; then
  echo "== Construction de l'image frr-wg =="
  docker build -t frr-wg:latest labs/03-final
fi

echo "== Déploiement de la topologie =="
(cd labs/03-final && sudo containerlab deploy -t topologie.clab.yml --reconfigure)

echo "== Configuration du tunnel WireGuard =="
./scripts/setup-wireguard.sh

echo "Labo prêt. Lancer : ./scripts/test-final.sh"
