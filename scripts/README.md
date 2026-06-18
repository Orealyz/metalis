# Scripts — METALIS

## Vue d'ensemble

| Script | Usage |
|---|---|
| `setup-vm-base.sh` | Crée et configure les VMs Debian de base via l'API Proxmox |
| `snapshot-backup.sh` | Déclenche un snapshot de toutes les VMs critiques |
| `vars.env.example` | Variables à personnaliser avant lancement |

## Prérequis

- Proxmox VE 9.2-1 installé et accessible
- `pvesh` disponible (CLI Proxmox, installé par défaut sur le nœud)
- Accès SSH au nœud Proxmox

## Utilisation

```bash
# 1. Copier et adapter les variables
cp vars.env.example vars.env
nano vars.env

# 2. Rendre les scripts exécutables
chmod +x setup-vm-base.sh snapshot-backup.sh

# 3. Créer les VMs
bash setup-vm-base.sh

# 4. Tester le script de snapshot manuellement
bash snapshot-backup.sh

# 5. Automatiser les snapshots via cron (sur le nœud Proxmox)
echo "0 2 * * * root /opt/mspr-metalis/scripts/snapshot-backup.sh >> /var/log/snapshots.log 2>&1" \
  > /etc/cron.d/proxmox-snapshots
```

## Variables disponibles (`vars.env`)

| Variable | Description | Exemple |
|---|---|---|
| `PROXMOX_NODE` | Nom du nœud Proxmox | `pve` |
| `STORAGE_POOL` | Pool de stockage Proxmox | `local-lvm` |
| `BRIDGE` | Bridge réseau principal | `vmbr0` |
| `ISO_STORAGE` | Stockage des ISOs | `local` |
| `VM_PASSWORD` | Mot de passe root des VMs | `ChangeMe123!` |

## Adaptation à un autre client

Pour redéployer sur un autre contexte :

1. Modifier `vars.env` (nœud, stockage, bridge)
2. Ajuster les IDs de VM dans `setup-vm-base.sh` si des VMs existent déjà
3. Adapter les tailles de disques selon les besoins du client
4. Relancer `setup-vm-base.sh`

Les scripts sont volontairement simples et commentés pour permettre cette réutilisation.
