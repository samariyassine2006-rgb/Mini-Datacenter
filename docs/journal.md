# Journal de bord

## Labo 01 : OSPF entre deux routeurs FRR
- Déploiement de 2 routeurs FRR et 2 PC avec Containerlab.
- Observation : après le déploiement, le voisin OSPF reste en 2-Way/DROther
  pendant environ 40 s (élection DR/BDR sur un lien Ethernet).
- Solution : `ip ospf network point-to-point` sur le lien r1-r2, l'adjacence
  passe en Full sans élection.
- Le message "Can't open vtysh.conf" est sans gravité (fichier optionnel).
- Test : ping PC1 -> PC2 réussi, TTL 62 (2 sauts routés).
