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
