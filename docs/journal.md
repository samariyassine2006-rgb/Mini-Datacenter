# Journal de bord

## Labo 01 : OSPF entre deux routeurs FRR
- Déploiement de 2 routeurs FRR et 2 PC avec Containerlab.
- Observation : après le déploiement, le voisin OSPF reste en 2-Way/DROther
  pendant environ 40 s (élection DR/BDR sur un lien Ethernet).
- Solution : `ip ospf network point-to-point` sur le lien r1-r2, l'adjacence
  passe en Full sans élection.
- Le message "Can't open vtysh.conf" est sans gravité (fichier optionnel).
- Test : ping PC1 -> PC2 réussi, TTL 62 (2 sauts routés).
- Correctif : la commande `ip ospf network point-to-point` n'était pas dans les
  `frr.conf` (tapée à la main dans vtysh). Elle est maintenant sauvegardée
  (`interface eth1`), l'adjacence Full est donc reproductible après un redéploiement.
- Ajouts : `passive-interface` sur le LAN (eth2) et sur `lo`, loopbacks
  10.255.0.1/32 et 10.255.0.2/32 annoncées en OSPF (conforme au plan d'adressage).
- PC1 et PC2 en `.100` (plage clients du plan) ; `.10` à `.50` sont réservés aux serveurs.

### Écarts volontaires entre le labo 01 et le plan final
- Lien direct r1-r2 en `10.0.12.0/30` et OSPF entre les deux sites : propre au labo.
  Dans le plan final, r1 et r2 passent par R-ISP (`10.0.1.0/30`, `10.0.2.0/30`),
  OSPF reste interne à chaque site et eBGP relie les sites à l'ISP.
- Pas de VLANs dans ce labo (PC directement sur eth2).
- Image `frrouting/frr:latest` : à figer sur la version réellement testée
  (relever avec `docker exec clab-ospf-lab-r1 vtysh -c "show version"`).

## Labo 02 : eBGP avec un ISP simulé
- 3 routeurs FRR : R1 (AS 65001), R-ISP (AS 65000), R2 (AS 65002).
- Chaque site n'annonce que son lien /30 (prefix-list + route-map en sortie) :
  les LAN ne sont jamais annoncés à l'ISP.
- FRR exige une route-map en entrée et en sortie pour échanger des routes en eBGP.
- Premier script de test erroné : le grep sur "Established" comptait aussi un
  champ JSON (bgpTimerUpEstablishedEpoch). Corrigé en cherchant "state":"Established".
- Résultat : R1 apprend 10.0.2.0/30 via 10.0.1.2 (chemin 65000 65002), R2 apprend
  10.0.1.0/30 via 10.0.2.1. Pings R1 <-> R2 : 0 % de perte, TTL 63.
- R-ISP renvoie à R1 son propre préfixe, que R1 écarte (anti-boucle d'AS-PATH).

## Labo 03 : topologie finale avec tunnel WireGuard
- Image de routeur personnalisée (FRR + wireguard-tools + nftables).
- Tunnel WireGuard R1 (10.99.0.1) <-> R2 (10.99.0.2), endpoints 10.0.1.1 et
  10.0.2.2, joignables grâce à eBGP à travers l'ISP.
- Clés générées au déploiement (rien de secret dans le dépôt).
- allowed-ips : les routes du site distant (10.x.0.0/16) passent par wg0.
- Preuve : traceroute PC1 -> web via 10.99.0.2, sans passer par l'ISP.

## Services, NAT et pare-feu (labo 03, jour 2)
- DHCP : dnsmasq sur R1 et R2 (port=0, DHCP seul), pool .100-.199, option DNS
  10.1.20.10 : les clients des deux sites utilisent le même serveur DNS.
- DNS : dnsmasq sur le conteneur dns, zone projet.local (host-record).
- NAT : masquerade sur eth1 uniquement ; les destinations 10.1.0.0/16 et
  10.2.0.0/16 sont exclues, donc le web voit l'IP réelle des clients de l'autre site.
- Pare-feu nftables : politique drop en input et forward ; autorisés
  explicitement : eBGP depuis l'ISP, WireGuard depuis le pair, DHCP, ping,
  DNS vers le site A, HTTP(S) vers le site B. Les serveurs ne peuvent pas
  initier de connexion (règle absente = refus).
- Preuve du pare-feu : un accès au port 179 de R2 via le tunnel est bloqué et
  le compteur du dernier "drop" augmente (comparaison avant/après).

### Problèmes rencontrés
- Avec DHCP, les clients gardaient la route par défaut du réseau de gestion
  Containerlab (eth0) et sortaient par la box, pas par R1. Correction :
  `ip route del default` avant `udhcpc`.
- udhcpc applique l'adresse et la route mais pas le DNS : Docker gère
  /etc/resolv.conf. Correction : un script udhcpc qui écrit les DNS reçus.
- Course au démarrage : WireGuard abandonne après 90 s de tentatives si la
  sous-couche BGP n'est pas prête. Le déploiement attend maintenant que R1 et R2
  se joignent à travers l'ISP, configure le tunnel, puis attend le handshake.
- Le test du compteur du pare-feu était trop faible (du bruit réseau le
  faisait passer) : il compare désormais le compteur avant et après l'accès bloqué.

## Scénarios de panne (labo 03, jour 3)
- Scénario 1 : coupure de eth1 de R1. La session BGP R1-ISP tombe, PC1 perd
  l'accès au site B mais garde ses services locaux (DNS du site A). Le site B
  n'est pas affecté. Après remise du lien, BGP se rétablit puis WireGuard refait
  son handshake dès qu'il y a du trafic.
- Scénario 2 : coupure de wg0. PC1 n'atteint plus le web du site B : aucun repli
  en clair par l'ISP, car les LAN ne sont pas annoncés en BGP et la seule route
  vers l'autre site passe par le tunnel. Le BGP avec l'ISP n'est pas affecté.
- Le script test-panne.sh mesure les temps de détection et de rétablissement.
