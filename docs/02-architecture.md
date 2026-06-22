# 02 — Architecture — METALIS

## Choix de l'hyperviseur

### Comparaison VirtualBox vs Proxmox VE

| Critère | VirtualBox | Proxmox VE |
|---|---|---|
| Type | Type 2 (s'installe sur un OS hôte) | Type 1 (bare-metal, pas d'OS hôte) |
| Compatibilité OS | Windows, macOS, Linux | Linux uniquement (hôte) |
| Performances | Moyennes (overhead OS hôte) | Bonnes (KVM direct) |
| Interface d'admin | GUI locale | Interface web centralisée |
| Snapshots | Oui, manuels | Oui, planifiables via cron/GUI |
| Licence | Gratuit (usage personnel) | Gratuit (sans support Proxmox) |
| Limites | Non adapté à un usage serveur 24/7 | Nécessite un matériel dédié |
| Cas d'usage pro | Postes de dev, tests locaux | Serveurs de production, labs |

### Choix retenu : Proxmox VE

METALIS travaille en 2×8 : les services doivent être disponibles 16h/jour minimum. VirtualBox tournant sur un OS hôte introduit un risque de stabilité (mises à jour Windows, redémarrages) incompatible avec cet usage.

Proxmox VE est installé directement sur le matériel (mini-PC dédié ou VPS), ce qui élimine l'OS hôte et améliore la stabilité. La gestion des snapshots planifiés et l'interface web permettent une administration sans ligne de commande au quotidien.

> **Limite acceptée :** un seul nœud Proxmox, pas de cluster. En contexte professionnel réel, on déploierait 2 nœuds en cluster pour la haute disponibilité.

## Architecture logique

### Machines virtuelles et conteneurs

```
Proxmox VE (hôte physique)
├── [CT] ct-vpn         192.168.1.208  — Debian 12            — WireGuard VPN
├── [VM] vm-dc          192.168.1.222  — Windows Server 2022  — Active Directory + DNS
├── [VM] vm-nas         192.168.1.219  — Debian 12            — Fichiers CAO (Samba)
├── [VM] vm-erp         192.168.1.221  — Debian 12            — Odoo 17 + PostgreSQL
├── [VM] vm-web         192.168.1.223  — Debian 12            — WordPress + WooCommerce (Nginx)
├── [VM] vm-supervision 192.168.1.224  — Debian 12            — Prometheus + Grafana + Loki
├── [VM] vm-client      192.168.1.211  — Windows 10           — Poste client de test
└── [VM] vm-clone       —             — Debian 12            — Template de base (prêt à cloner)
```

### Rôles et justifications

**vm-dc** — Active Directory  
Centralise l'authentification. Les utilisateurs ateliers, bureaux et commerciaux s'authentifient via leurs identifiants AD. Permet de gérer les droits sur les partages Samba depuis un point unique.

**vm-nas** — Serveur de fichiers  
Remplace le NAS vieillissant. Samba expose les partages aux postes Windows. Le volume de données CAO (SolidWorks) est sur un disque virtuel dédié, séparé de l'OS, pour faciliter les sauvegardes.

**vm-erp** — Odoo + PostgreSQL  
Instance dédiée avec 4 vCPU et 8 Go RAM pour absorber les pics de charge. La base PostgreSQL est sur un volume séparé. Odoo est exposé uniquement en interne (reverse proxy Nginx sur vm-web pour l'accès public si nécessaire).

**vm-web** — Site vitrine + WooCommerce  
Isolée de l'ERP. Un crash ou une mise à jour WooCommerce n'affecte pas la production. Nginx sert WordPress + WooCommerce. L'intégration Odoo↔WooCommerce se fait via l'API Odoo.

**vm-client** — Poste de test  
Permet de valider les accès réseau, les droits Samba et le comportement utilisateur sans toucher aux postes physiques.

**ct-vpn** — WireGuard (conteneur LXC)  
Conteneur léger dédié au VPN. Isolé des VMs de production pour limiter la surface d'attaque. Écoute sur UDP 51820 et donne accès au réseau interne pour les commerciaux en télétravail et le prestataire CNC.

**vm-supervision** — Prometheus + Grafana + Loki  
Collecte les métriques et logs de toutes les VMs. Les alertes sont envoyées sur Telegram via Alertmanager. Isolée pour ne pas impacter la production si elle tombe.

**vm-clone** — Template de base  
VM Debian 12 préconfigurée (ssh, outils de base, agent Proxmox) servant de point de départ pour créer rapidement de nouvelles VMs. Ne tourne pas en production.

## Réseau virtualisé

### VLANs

| VLAN | Nom | Usage |
|---|---|---|
| VLAN 10 | Bureaux | Postes administratifs, commerciaux |
| VLAN 20 | Atelier | CNC, douchettes, imprimantes étiquettes, tablettes |
| VLAN 30 | Serveurs | VMs Proxmox |
| VLAN 40 | DMZ | vm-web (exposition publique) |
| VLAN 99 | Management | Interface Proxmox (accès restreint) |

### Adressage IP

> Les VMs sont déployées sur un réseau plat `192.168.1.0/24` (environnement lab). Le découpage VLAN reste l'architecture cible pour un déploiement en production.

| VM / CT | ID Proxmox | IP fixe |
|---|---|---|
| `ct-vpn` (CT) | 100 | 192.168.1.208 |
| `vm-client` | 101 | 192.168.1.211 |
| `vm-dc` | 102 | 192.168.1.222 |
| `vm-supervision` | 103 | 192.168.1.224 |
| `vm-erp` | 104 | 192.168.1.221 |
| `vm-nas` | 105 | 192.168.1.219 |
| `vm-clone` | 106 | — |
| `vm-web` | 107 | 192.168.1.223 |

### Accès distant

- **Commerciaux en télétravail** : VPN WireGuard déployé sur `ct-vpn` (192.168.1.208, port UDP 51820), tunnelé vers le réseau interne
- **Prestataire CNC** : accès VPN restreint via `ct-vpn`, limité aux ressources atelier via règles firewall Proxmox

## Estimation des ressources

### Matériel cible (mini-PC ou VPS)

| Ressource | Minimum | Recommandé |
|---|---|---|
| CPU | 8 cœurs physiques | 12 cœurs |
| RAM | 24 Go | 32 Go |
| Stockage OS | 120 Go SSD | 120 Go SSD |
| Stockage données | 1 To HDD/SSD | 2 To |

### Répartition par VM

| VM / CT | vCPU | RAM | Disque OS | Disque données |
|---|---|---|---|---|
| ct-vpn (CT) | 1 | 512 Mo | 8 Go | — |
| vm-dc | 2 | 4 Go | 60 Go | — |
| vm-nas | 2 | 4 Go | 40 Go | 500 Go |
| vm-erp | 4 | 8 Go | 60 Go | 100 Go |
| vm-web | 2 | 4 Go | 40 Go | — |
| vm-supervision | 2 | 4 Go | 40 Go | — |
| vm-client | 2 | 4 Go | 60 Go | — |
| vm-clone | 1 | 2 Go | 20 Go | — |
| **Total** | **16** | **30,5 Go** | **328 Go** | **600 Go** |
