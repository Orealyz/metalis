#!/bin/bash
# snapshot-backup.sh — Snapshots automatiques des VMs critiques METALIS
# Usage : bash snapshot-backup.sh
# Recommandé : planifier via cron sur le nœud Proxmox
#
#   Snapshots toutes les 4h (vm-nas, vm-erp, vm-web) :
#   0 */4 * * * root /opt/mspr-metalis/scripts/snapshot-backup.sh --mode 4h >> /var/log/snapshots-metalis.log 2>&1
#
#   Snapshots quotidiens (vm-dc, vm-supervision) :
#   0 2 * * * root /opt/mspr-metalis/scripts/snapshot-backup.sh --mode daily >> /var/log/snapshots-metalis.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/vars.env" ]] && source "$SCRIPT_DIR/vars.env"

PROXMOX_NODE="${PROXMOX_NODE:-pve}"
DATE=$(date +%Y%m%d-%H%M)
RETENTION_DAYS="${SNAPSHOT_RETENTION_DAYS:-7}"
MODE="${1:-daily}"

# VMs snapshots toutes les 4h (RPO 4h) : vm-nas, vm-erp, vm-web
FOURH_VMS="105:7 104:7 107:7"

# VMs snapshots quotidiens (RPO 24h) : vm-dc, vm-supervision
DAILY_VMS="102:28 103:28"

echo "=== Snapshots METALIS [$MODE] — $DATE ==="

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
        --vmstate 0

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
# Snapshots toutes les 4h
# -------------------------------------------------------
if [[ "$MODE" == "4h" ]]; then
    echo "--- Snapshots 4h : vm-nas (105), vm-erp (104), vm-web (107) ---"
    for entry in $FOURH_VMS; do
        VMID="${entry%%:*}"
        RETENTION="${entry##*:}"
        snapshot_vm "$VMID"
        purge_old_snapshots "$VMID" "$RETENTION"
    done
fi

# -------------------------------------------------------
# Snapshots quotidiens
# -------------------------------------------------------
if [[ "$MODE" == "daily" ]]; then
    echo "--- Snapshots quotidiens : vm-dc (102), vm-supervision (103) ---"
    for entry in $DAILY_VMS; do
        VMID="${entry%%:*}"
        RETENTION="${entry##*:}"
        snapshot_vm "$VMID"
        purge_old_snapshots "$VMID" "$RETENTION"
    done
fi

echo "=== Terminé — $DATE ==="
