#!/bin/bash
# snapshot-backup.sh — Snapshots automatiques des VMs critiques METALIS
# Usage : bash snapshot-backup.sh
# Recommandé : planifier via cron sur le nœud Proxmox
#   0 2 * * * root /opt/mspr-metalis/scripts/snapshot-backup.sh >> /var/log/snapshots-metalis.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/vars.env" ]] && source "$SCRIPT_DIR/vars.env"

PROXMOX_NODE="${PROXMOX_NODE:-pve}"
DATE=$(date +%Y%m%d-%H%M)
RETENTION_DAYS="${SNAPSHOT_RETENTION_DAYS:-7}"

# VMs à sauvegarder (VMID:Rétention en jours)
DAILY_VMS="101:7 102:7"    # vm-nas, vm-erp — snapshot quotidien
WEEKLY_VMS="100:28 103:28" # vm-dc, vm-web — snapshot hebdomadaire

echo "=== Snapshots METALIS — $DATE ==="

# -------------------------------------------------------
# Fonction : créer un snapshot
# -------------------------------------------------------
snapshot_vm() {
    local VMID=$1
    local SNAP_NAME="auto-$DATE"

    echo "Snapshot VM $VMID : $SNAP_NAME"
    pvesh create /nodes/$PROXMOX_NODE/qemu/$VMID/snapshot \
        --snapname "$SNAP_NAME" \
        --description "Snapshot automatique du $DATE" \
        --vmstate 0  # Sans état mémoire (plus rapide)

    echo "Snapshot $VMID OK"
}

# -------------------------------------------------------
# Fonction : purger les vieux snapshots
# -------------------------------------------------------
purge_old_snapshots() {
    local VMID=$1
    local RETENTION=$2

    echo "Purge snapshots > ${RETENTION}j pour VM $VMID"

    pvesh get /nodes/$PROXMOX_NODE/qemu/$VMID/snapshot --output-format json \
        | python3 -c "
import sys, json, subprocess
from datetime import datetime, timedelta

snaps = json.load(sys.stdin)
cutoff = datetime.now() - timedelta(days=$RETENTION)

for s in snaps:
    name = s.get('name', '')
    if not name.startswith('auto-'):
        continue
    try:
        snap_date = datetime.strptime(name, 'auto-%Y%m%d-%H%M')
        if snap_date < cutoff:
            print(f'Suppression : {name}')
            subprocess.run(['pvesh', 'delete', f'/nodes/$PROXMOX_NODE/qemu/$VMID/snapshot/{name}'], check=True)
    except ValueError:
        pass
"
}

# -------------------------------------------------------
# Snapshots quotidiens
# -------------------------------------------------------
echo "--- Snapshots quotidiens ---"
for entry in $DAILY_VMS; do
    VMID="${entry%%:*}"
    RETENTION="${entry##*:}"
    snapshot_vm "$VMID"
    purge_old_snapshots "$VMID" "$RETENTION"
done

# -------------------------------------------------------
# Snapshots hebdomadaires (uniquement le lundi)
# -------------------------------------------------------
if [[ $(date +%u) -eq 1 ]]; then
    echo "--- Snapshots hebdomadaires (lundi) ---"
    for entry in $WEEKLY_VMS; do
        VMID="${entry%%:*}"
        RETENTION="${entry##*:}"
        snapshot_vm "$VMID"
        purge_old_snapshots "$VMID" "$RETENTION"
    done
else
    echo "--- Snapshots hebdomadaires ignorés (pas lundi) ---"
fi

echo "=== Terminé — $DATE ==="
