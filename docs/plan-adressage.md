# Plan d'adressage

Projet : infrastructure réseau virtualisée multi-sites
Auteurs : Yassine SAMARI, Achraf TALHAOUI
Version : v1 (schéma associé : `docs/schema-adressage.svg`)

## 1. Plages réservées

| Usage | Plage | Remarque |
|---|---|---|
| Site A | `10.1.0.0/16` | un `/24` par VLAN |
| Site B | `10.2.0.0/16` | un `/24` par VLAN |
| Liens vers l'ISP | `10.0.1.0/30`, `10.0.2.0/30` | un `/30` par lien point à point |
| Tunnel WireGuard | `10.99.0.0/30` | entre R1 et R2 |
| Loopbacks | `10.255.0.0/24` | un `/32` par routeur |

Aucune plage ne se chevauche : les agrégats `10.1.0.0/16` et `10.2.0.0/16`
peuvent donc être utilisés tels quels dans les routes et les règles de pare-feu.

## 2. Conventions

- Passerelle d'un VLAN : toujours `.1` (adresse du routeur du site).
- Serveurs en IP fixe : `.10` à `.50`.
- Pool DHCP : `.100` à `.199`.
- Sur un lien `/30` : côté site `.1`, côté ISP `.2` (sauf pour le lien R-ISP ↔ R2, voir ci-dessous).

## 3. Routeurs : identifiants

| Routeur | Rôle | AS | Loopback (router-id) |
|---|---|---|---|
| R1 | Routeur du site A | 65001 | `10.255.0.1/32` |
| R2 | Routeur du site B | 65002 | `10.255.0.2/32` |
| R-ISP | Opérateur simulé | 65000 | `10.255.0.3/32` |

## 4. Liens point à point

| Lien | Réseau | Extrémité 1 | Extrémité 2 |
|---|---|---|---|
| R1 ↔ R-ISP | `10.0.1.0/30` | R1 `eth1` : `10.0.1.1` | R-ISP `eth1` : `10.0.1.2` |
| R-ISP ↔ R2 | `10.0.2.0/30` | R-ISP `eth2` : `10.0.2.1` | R2 `eth1` : `10.0.2.2` |
| Tunnel R1 ↔ R2 | `10.99.0.0/30` | R1 `wg0` : `10.99.0.1` | R2 `wg0` : `10.99.0.2` |

Extrémités du tunnel WireGuard (endpoints) : `10.0.1.1` (R1) et `10.0.2.2` (R2).
Elles doivent pouvoir se joindre à travers l'ISP.

## 5. Site A (`10.1.0.0/16`)

Routeur R1, interface `eth2` en trunk 802.1Q vers le switch.

| VLAN | Réseau | Passerelle | Interface R1 | Machines |
|---|---|---|---|---|
| 10 (clients) | `10.1.10.0/24` | `10.1.10.1` | `eth2.10` | PC1 en DHCP (`.100` à `.199`) |
| 20 (serveurs) | `10.1.20.0/24` | `10.1.20.1` | `eth2.20` | DNS Bind9 : `10.1.20.10` |

## 6. Site B (`10.2.0.0/16`)

Routeur R2, interface `eth2` en trunk 802.1Q vers le switch.

| VLAN | Réseau | Passerelle | Interface R2 | Machines |
|---|---|---|---|---|
| 10 (clients) | `10.2.10.0/24` | `10.2.10.1` | `eth2.10` | PC2 en DHCP (`.100` à `.199`) |
| 20 (serveurs) | `10.2.20.0/24` | `10.2.20.1` | `eth2.20` | Web Nginx : `10.2.20.10` |

## 7. Récapitulatif des adresses

| Équipement | Interface | Adresse | Réseau |
|---|---|---|---|
| R1 | `lo` | `10.255.0.1/32` | loopback |
| R1 | `eth1` | `10.0.1.1/30` | lien ISP |
| R1 | `eth2.10` | `10.1.10.1/24` | VLAN 10 site A |
| R1 | `eth2.20` | `10.1.20.1/24` | VLAN 20 site A |
| R1 | `wg0` | `10.99.0.1/30` | tunnel |
| R-ISP | `lo` | `10.255.0.3/32` | loopback |
| R-ISP | `eth1` | `10.0.1.2/30` | lien vers R1 |
| R-ISP | `eth2` | `10.0.2.1/30` | lien vers R2 |
| R2 | `lo` | `10.255.0.2/32` | loopback |
| R2 | `eth1` | `10.0.2.2/30` | lien ISP |
| R2 | `eth2.10` | `10.2.10.1/24` | VLAN 10 site B |
| R2 | `eth2.20` | `10.2.20.1/24` | VLAN 20 site B |
| R2 | `wg0` | `10.99.0.2/30` | tunnel |
| PC1 | `eth1` | DHCP (`10.1.10.100` à `.199`) | VLAN 10 site A |
| DNS Bind9 | `eth1` | `10.1.20.10/24` | VLAN 20 site A |
| PC2 | `eth1` | DHCP (`10.2.10.100` à `.199`) | VLAN 10 site B |
| Web Nginx | `eth1` | `10.2.20.10/24` | VLAN 20 site B |

## 8. Routage

### OSPF (dans chaque site)
- Annonce les VLANs et la loopback du routeur.
- Les interfaces vers l'ISP ne participent pas à OSPF.

### eBGP (entre les sites et l'ISP)
- R1 (AS 65001) ↔ R-ISP (AS 65000) sur `10.0.1.0/30`.
- R2 (AS 65002) ↔ R-ISP (AS 65000) sur `10.0.2.0/30`.
- R1 annonce `10.0.1.0/30`, R2 annonce `10.0.2.0/30`, pour que les extrémités du
  tunnel se joignent.
- Les LAN des sites ne sont pas annoncés à l'ISP.

### Routes à travers le tunnel
- R1 : `10.2.0.0/16` via `10.99.0.2` (interface `wg0`).
- R2 : `10.1.0.0/16` via `10.99.0.1` (interface `wg0`).
- Routes statiques au début, éventuellement OSPF sur `wg0` ensuite.

### NAT
- Sur R1 et R2, traduction d'adresses uniquement en sortie `eth1`.
- Le trafic vers l'autre site (`10.1.0.0/16` ↔ `10.2.0.0/16`) ne doit pas être traduit.

## 9. Services

| Service | Emplacement | Détail |
|---|---|---|
| DHCP | R1 et R2 (chacun pour son site) | pool `.100` à `.199` du VLAN 10, passerelle `.1`, DNS `10.1.20.10` |
| DNS (Bind9) | site A, `10.1.20.10` | zone du projet, doit aussi résoudre `web` → `10.2.20.10` |
| Web (Nginx) | site B, `10.2.20.10` | accessible depuis le site A à travers le tunnel |
| Pare-feu (nftables) | sur R1 et R2 | politique par défaut à refuser, flux autorisés explicitement |

## 10. Vérifications à prévoir

- `ping` PC1 → passerelle `10.1.10.1`, puis PC1 → PC2.
- `traceroute` PC1 → PC2 : le trafic passe par `10.99.0.x`, pas par R-ISP.
- `show ip bgp summary` sur R1, R2 et R-ISP : sessions établies.
- `show ip ospf neighbor` selon la topologie retenue.
- `wg show` : handshake récent entre R1 et R2.
- `dig web.[domaine]` depuis PC2 : réponse `10.2.20.10`.

## Annexe : écarts entre le plan initial et la réalisation

- Segmentation : les sous-interfaces 802.1Q (`eth2.10`, `eth2.20`) sont remplacées par
  deux interfaces distinctes, `eth2` (clients, `10.x.10.0/24`) et `eth3` (serveurs,
  `10.x.20.0/24`). Les adresses du plan sont conservées.
- OSPF : étudié dans le labo 01 (lien de test `10.0.12.0/30`) ; non utilisé dans la
  topologie finale, où chaque site n'a qu'un routeur.
- DNS et DHCP : dnsmasq à la place de Bind9. Le DHCP est porté par chaque routeur
  comme prévu, le DNS par le serveur du site A (`10.1.20.10`).
- Routes inter-sites : routes statiques via `wg0`.
