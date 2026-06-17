#!/bin/bash
# setup-vm-base.sh — Création des VMs Debian de base pour METALIS
# Usage : bash setup-vm-base.sh
# Prérequis : exécuter depuis le nœud Proxmox en root

set -euo pipefail

# Charger les variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/vars.env" ]]; then
    source "$SCRIPT_DIR/vars.env"
else
    echo "ERREUR : vars.env introuvable. Copier vars.env.example et l'adapter."
    exit 1
fi

# Valeurs par défaut
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
STORAGE_POOL="${STORAGE_POOL:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
VM_PASSWORD="${VM_PASSWORD:-ChangeMe123!}"

echo "=== Déploiement METALIS sur le nœud $PROXMOX_NODE ==="

# -------------------------------------------------------
# Fonction : créer une VM Debian via cloud-init
# Arguments : $1=VMID $2=Nom $3=vCPU $4=RAM(Mo) $5=Disque(Go) $6=IP $7=VLAN
# -------------------------------------------------------
create_vm() {
    local VMID=$1
    local NAME=$2
    local CPU=$3
    local RAM=$4
    local DISK=$5
    local IP=$6
    local VLAN=$7

    echo "--- Création VM $VMID ($NAME) ---"

    # Créer la VM
    pvesh create /nodes/$PROXMOX_NODE/qemu \
        --vmid $VMID \
        --name $NAME \
        --memory $RAM \
        --cores $CPU \
        --net0 "virtio,bridge=$BRIDGE,tag=$VLAN" \
        --ostype l26 \
        --scsi0 "${STORAGE_POOL}:${DISK}" \
        --ide2 "${STORAGE_POOL}:cloudinit" \
        --boot order=scsi0 \
        --serial0 socket \
        --vga serial0 \
        --ipconfig0 "ip=${IP}/24,gw=192.168.30.1" \
        --cipassword "$VM_PASSWORD" \
        --ciuser adminmspr

    echo "VM $VMID ($NAME) créée — IP : $IP"
}

# -------------------------------------------------------
# Création des VMs
# -------------------------------------------------------
# VMID  Nom           vCPU  RAM    Disque  IP               VLAN
create_vm 100 "vm-dc"    2   4096   60     "192.168.30.10"  30
create_vm 101 "vm-nas"   2   4096   40     "192.168.30.20"  30
create_vm 102 "vm-erp"   4   8192   60     "192.168.30.30"  30
create_vm 103 "vm-web"   2   4096   40     "192.168.40.10"  40
create_vm 104 "vm-client" 2  4096   60     "192.168.10.50"  10

# Disque données séparé pour vm-nas (CAO)
echo "--- Ajout disque données 500 Go sur vm-nas (101) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/101/config \
    --scsi1 "${STORAGE_POOL}:500"

# Disque données séparé pour vm-erp (PostgreSQL)
echo "--- Ajout disque données 100 Go sur vm-erp (102) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/102/config \
    --scsi1 "${STORAGE_POOL}:100"

echo ""
echo "=== Création terminée ==="
echo "Démarrer les VMs manuellement depuis l'interface Proxmox"
echo "puis installer Debian 12 via ISO ou cloud-init."
echo ""
echo "Ordre de démarrage recommandé : vm-dc (100) → vm-nas (101) → vm-erp (102) → vm-web (103)"
