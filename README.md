# Infrastructure réseau virtualisée multi-sites

Projet réalisé par **Yassine SAMARI** et **Achraf TALHAOUI**
année 2026-2027

## Présentation

Ce projet simule un réseau d'entreprise composé de deux sites (A et B) reliés
par un opérateur simulé (ISP), avec un tunnel VPN WireGuard direct entre les
deux sites. Les routeurs FRRouting s'exécutent dans des conteneurs Docker
orchestrés par Containerlab.

L'objectif est de mettre en œuvre, de façon reproductible, les briques
classiques d'une infrastructure réseau : routage dynamique, segmentation,
services d'infrastructure, sécurité et interconnexion chiffrée des sites.

## Objectifs

- Routage dynamique : eBGP entre les sites et l'ISP (OSPF étudié dans le labo 01)
- Segmentation clients / serveurs (réseaux `10.x.10.0/24` et `10.x.20.0/24`, interfaces distinctes)
- NAT en sortie vers l'ISP
- VPN site-à-site WireGuard entre R1 et R2
- Services : DNS et DHCP (dnsmasq), serveur web (Nginx)
- Filtrage : pare-feu nftables sur les routeurs
- Tests de fonctionnement et de résilience (pannes, convergence)

## Architecture

Le schéma d'architecture est disponible dans `docs/schema-architecture.svg`
le plan d'adressage dans `docs/plan-adressage.md` (schéma : `docs/schema-adressage.svg`)
et le journal de bord dans `docs/journal.md`.

| Élément | Rôle |
|---|---|
| Site A (AS 65001) | Routeur R1 (FRRouting), réseaux `10.1.10.0/24` (clients) et `10.1.20.0/24` (serveurs), PC1 (client DHCP), serveur DNS dnsmasq |
| Site B (AS 65002) | Routeur R2 (FRRouting), réseaux `10.2.10.0/24` (clients) et `10.2.20.0/24` (serveurs), PC2 (client DHCP), serveur web Nginx |
| ISP (AS 65000) | Routeur R-ISP, eBGP avec R1 et R2 |

### Liens

| Lien | Réseau | Protocole |
|---|---|---|
| R1 ↔ R-ISP | `10.0.1.0/30` | eBGP |
| R-ISP ↔ R2 | `10.0.2.0/30` | eBGP |
| R1 ↔ R2 (tunnel WireGuard) | `10.99.0.0/30` | Routes statiques via `wg0` |

### Principe de fonctionnement

- Les routeurs R1 et R2 n'annoncent à l'ISP que les adresses nécessaires à
  l'établissement du tunnel. Les LAN des sites ne sont pas annoncés en BGP.
- Le trafic entre les LAN des deux sites circule dans le tunnel WireGuard
  et ne transite donc pas en clair par l'ISP.
- Le NAT sur R1 et R2 donne aux clients un accès vers l'extérieur (l'ISP).

## Technologies

- Containerlab, Docker
- FRRouting (OSPF, BGP)
- dnsmasq (DHCP et DNS), Nginx
- nftables
- WireGuard

## Structure du dépôt

```
Reseau-entreprise-virtualise/
├── labs/         # labos progressifs (01-ospf, ...) : topologie .clab.yml + configs
├── configs/      # configurations de la topologie finale (r1, r2, isp)
├── scripts/      # déploiement et tests automatisés
├── docs/         # schéma, plan d'adressage, rapport
└── README.md
```

## Prérequis

- Linux (natif, VM ou WSL2)
- Docker
- Containerlab
- Outils de diagnostic : tcpdump, traceroute

## Déploiement

```bash
# Cloner le dépôt
git clone https://github.com/samariyassine2006-rgb/Reseau-entreprise-virtualise.git
cd Reseau-entreprise-virtualise

# Déployer la topologie finale (images, topologie, tunnel WireGuard)
./scripts/deploy-final.sh

# Détruire la topologie
cd labs/03-final && sudo containerlab destroy -t topologie.clab.yml
```

## Tests

```bash
./scripts/test-ospf.sh   # labo 01 ; un script par labo
./scripts/test-bgp.sh   # labo 02 : eBGP
./scripts/test-final.sh   # labo 03 : réseau de bout en bout
./scripts/test-services.sh   # labo 03 : DHCP, DNS, NAT, pare-feu
./scripts/test-panne.sh   # labo 03 : scénarios de panne
```

Scénarios couverts :

- Connectivité PC1 ↔ PC2 à travers le tunnel (traceroute : le trafic ne doit pas passer par R-ISP)
- Attribution DHCP et résolution DNS (dnsmasq, site A)
- Accès au serveur web Nginx (site B) depuis le site A
- Règles de pare-feu nftables (flux autorisés et bloqués)
- Coupure du lien R1 ↔ R-ISP ou du tunnel, et mesure du temps de convergence

Les sorties des tests sont consignées dans `docs/resultats-tests.txt`, le journal de bord dans `docs/journal.md`.

## Avancement

- [x] Schéma d'architecture (v1)
- [x] Plan d'adressage
- [x] Topologie Containerlab de base (labo 01 : 2 routeurs, 2 PC)
- [x] OSPF (labo 01 ; non utilisé dans la topologie finale, un seul routeur par site)
- [x] eBGP avec l'ISP
- [x] Segmentation clients/serveurs, DHCP, DNS, serveur web
- [x] NAT et pare-feu nftables
- [x] Tunnel WireGuard
- [x] Tests et rapport

## Livrables

- Schéma d'architecture
- Scripts de déploiement
- Rapport de tests
## Labo 03 : topologie finale (eBGP + WireGuard)

    ./scripts/deploy-final.sh
    ./scripts/test-final.sh
    cd labs/03-final && sudo containerlab destroy -t topologie.clab.yml

Le test vérifie les sessions BGP, le tunnel WireGuard (handshake), l'accès
du PC1 au serveur Nginx du site B et que le trafic emprunte bien le tunnel.

## Labo 03 (suite) : services, NAT et pare-feu

    ./scripts/deploy-final.sh
    ./scripts/test-final.sh
    ./scripts/test-services.sh

DHCP et DNS (dnsmasq), NAT en sortie sans traduction entre sites, pare-feu
nftables à politique de refus par défaut sur R1 et R2.

## Scénarios de panne

    ./scripts/test-panne.sh

Deux scénarios : coupure du lien R1 vers l'ISP (la session BGP tombe, le site A
perd l'accès au site B mais garde ses services locaux, puis rétablissement) et
coupure du tunnel WireGuard (aucun repli en clair par l'ISP).

## Démonstration

Le déroulé de la démonstration est décrit dans `docs/demo.md`.

## Limites et pistes d'amélioration

- Les réseaux clients et serveurs sont portés par des interfaces distinctes
  (eth2 et eth3) : les VLAN 802.1Q du plan initial ne sont pas implémentés.
- OSPF est étudié dans le labo 01 mais n'est pas utilisé dans la topologie finale,
  où chaque site n'a qu'un routeur.
- Un seul serveur DNS (site A) : pas de redondance.
- Pas de haute disponibilité des routeurs (VRRP/Keepalived) ni de second tunnel.
- Les clés WireGuard sont générées à chaque déploiement : aucun secret dans le dépôt.
