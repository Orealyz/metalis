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
├── [CT] ct-vpn        — Debian 12            — WireGuard VPN
├── [VM] vm-dc         — Windows Server 2022  — Active Directory + DNS
├── [VM] vm-nas        — Debian 12            — Fichiers CAO (Samba)
├── [VM] vm-erp        — Debian 12            — Odoo 17 + PostgreSQL
├── [VM] vm-web        — Debian 12            — WordPress + WooCommerce (Nginx)
├── [VM] vm-supervision — Debian 12           — Prometheus + Grafana + Loki
├── [VM] vm-client     — Windows 10           — Poste client de test
└── [VM] vm-clone      — Debian 12            — Template de base (prêt à cloner)
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

> Les VMs sont déployées sur un réseau plat `10.33.81.0/24` (environnement lab). Le découpage VLAN reste l'architecture cible pour un déploiement en production.

| VM / CT | ID Proxmox | IP fixe |
|---|---|---|
| `ct-vpn` (CT) | 100 | 10.33.81.208 |
| `vm-client` | 101 | 10.33.81.211 |
| `vm-dc` | 102 | 10.33.81.222 |
| `vm-supervision` | 103 | 10.33.81.224 |
| `vm-erp` | 104 | 10.33.81.221 |
| `vm-nas` | 105 | 10.33.81.219 |
| `vm-clone` | 106 | — |
| `vm-web` | 107 | 10.33.81.223 |

### Accès distant

- **Commerciaux en télétravail** : VPN WireGuard déployé sur vm-erp (port UDP 51820), tunnelé vers le VLAN Serveurs
- **Prestataire CNC** : accès VPN restreint, limité au VLAN 20 (atelier) via règles firewall Proxmox

## Estimation des ressources

### Matériel cible (mini-PC ou VPS)

| Ressource | Minimum | Recommandé |
|---|---|---|
| CPU | 8 cœurs physiques | 12 cœurs |
| RAM | 24 Go | 32 Go |
| Stockage OS | 120 Go SSD | 120 Go SSD |
| Stockage données | 1 To HDD/SSD | 2 To |

### Répartition par VM

| VM | vCPU | RAM | Disque OS | Disque données |
|---|---|---|---|---|
| vm-dc | 2 | 4 Go | 60 Go | — |
| vm-nas | 2 | 4 Go | 40 Go | 500 Go |
| vm-erp | 4 | 8 Go | 60 Go | 100 Go |
| vm-web | 2 | 4 Go | 40 Go | — |
| vm-client | 2 | 4 Go | 60 Go | — |
| **Total** | **12** | **24 Go** | **260 Go** | **600 Go** |
