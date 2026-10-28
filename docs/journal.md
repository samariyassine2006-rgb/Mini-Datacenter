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
