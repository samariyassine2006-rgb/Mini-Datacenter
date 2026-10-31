# Script de la démonstration vidéo (2 à 3 minutes)

Préparer deux terminaux Ubuntu côte à côte, le dépôt cloné, les images déjà construites.

## 1. Présentation (20 s)
Ouvrir `docs/schema-architecture.svg`. Dire : deux sites d'entreprise reliés par un
ISP simulé en eBGP, un tunnel WireGuard entre les routeurs, DHCP/DNS/web, NAT et
pare-feu. Tout est en conteneurs, déployé par un seul fichier de topologie.

## 2. Déploiement (30 s)
    ./scripts/deploy-final.sh
Montrer les messages : sous-couche opérationnelle, tunnel configuré, handshake effectué.

## 3. Preuves, une commande par brique (60 s)
    docker exec clab-final-risp vtysh -c "show bgp summary"
    docker exec clab-final-r1 wg show wg0
    docker exec clab-final-pc1 ip -4 addr show eth1
    docker exec clab-final-pc1 nslookup web.projet.local 10.1.20.10
    docker exec clab-final-pc1 wget -qO- http://10.2.20.10 | head -n 5
    docker exec clab-final-pc1 traceroute -n -m 3 -w 1 -q 1 10.2.20.10
    docker exec clab-final-r1 nft list chain ip nat postrouting
À dire : le trafic du site A vers le site B passe par `10.99.0.2` (le tunnel), pas par
l'ISP ; l'adresse du client vient du DHCP ; le NAT ne traduit pas le trafic inter-sites.

## 4. Tests automatiques (20 s)
    ./scripts/test-final.sh
    ./scripts/test-services.sh
Montrer les lignes `[OK]` et le résultat final.

## 5. Panne (40 s)
    ./scripts/test-panne.sh
À dire : coupure du lien vers l'ISP, la session BGP tombe, le site A perd l'accès au
site B mais garde ses services locaux ; rétablissement automatique. Coupure du tunnel :
aucun repli en clair par l'ISP.

## 6. Conclusion (10 s)
Projet reproductible depuis GitHub, documenté, testé de bout en bout.
