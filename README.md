# METALIS — Infrastructure virtualisée

> **Secteur :** Fabrication métal/bois sur mesure + e-commerce  
> **Effectif :** ~40 personnes, production en 2×8  
> **Hyperviseur :** Proxmox VE sur mini-PC/VPS dédié

## Résumé du projet

METALIS souffre d'une infrastructure informatique vieillissante et non redondée : NAS saturé, ERP lent, Wi-Fi atelier instable, pas de plan de sauvegarde formel. Une panne NAS l'an dernier a causé plusieurs jours de perte.

L'objectif est de virtualiser les services critiques (fichiers CAO, ERP Odoo, accès distants) pour améliorer la disponibilité et réduire le risque d'interruption de production.

## VMs déployées

| VM | OS | Rôle | vCPU | RAM | Stockage |
|---|---|---|---|---|---|
| `vm-dc` | Windows Server 2022 | Active Directory + DNS | 2 | 4 Go | 60 Go |
| `vm-nas` | Debian 12 | Fichiers CAO (Samba) + sauvegardes | 2 | 4 Go | 500 Go |
| `vm-erp` | Debian 12 | Odoo 17 + PostgreSQL | 4 | 8 Go | 100 Go |
| `vm-web` | Debian 12 | WooCommerce + WordPress (Nginx) | 2 | 4 Go | 40 Go |
| `vm-client` | Windows 10 | Poste client de test | 2 | 4 Go | 60 Go |

## Accès rapide

- [Analyse des besoins](./docs/01-analyse-besoins.md)
- [Architecture & choix techniques](./docs/02-architecture.md)
- [Continuité de service](./docs/03-continuite-service.md)
- [Limites et compromis](./docs/04-limites-compromis.md)
- [Schéma architecture logique](./schemas/architecture-logique.md)
- [Schéma réseau](./schemas/reseau.md)
- [Scripts et automatisation](./scripts/README.md)

## Déploiement rapide

```bash
# 1. Cloner le dépôt sur le nœud Proxmox
git clone https://github.com/Orealyz/metalis.git /opt/mspr-metalis

# 2. Configurer les variables
cp scripts/vars.env.example scripts/vars.env
nano scripts/vars.env

# 3. Lancer la création des VMs de base
bash scripts/setup-vm-base.sh

# 4. Configurer les snapshots automatiques
bash scripts/snapshot-backup.sh
```

> Les ajustements effectués en cours de projet sont documentés dans [docs/04-limites-compromis.md](./docs/04-limites-compromis.md).
