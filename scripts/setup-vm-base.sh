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
GW="192.168.1.254"
MASK="24"

echo "=== Déploiement METALIS sur le nœud $PROXMOX_NODE ==="

# -------------------------------------------------------
# Fonction : créer une VM Debian via cloud-init
# Arguments : $1=VMID $2=Nom $3=vCPU $4=RAM(Mo) $5=Disque(Go) $6=IP
# -------------------------------------------------------
create_vm() {
    local VMID=$1
    local NAME=$2
    local CPU=$3
    local RAM=$4
    local DISK=$5
    local IP=$6

    echo "--- Création VM $VMID ($NAME) ---"

    pvesh create /nodes/$PROXMOX_NODE/qemu \
        --vmid $VMID \
        --name $NAME \
        --memory $RAM \
        --cores $CPU \
        --net0 "virtio,bridge=$BRIDGE" \
        --ostype l26 \
        --scsi0 "${STORAGE_POOL}:${DISK}" \
        --ide2 "${STORAGE_POOL}:cloudinit" \
        --boot order=scsi0 \
        --serial0 socket \
        --vga serial0 \
        --ipconfig0 "ip=${IP}/${MASK},gw=${GW}" \
        --cipassword "$VM_PASSWORD" \
        --ciuser adminmspr

    echo "VM $VMID ($NAME) créée — IP : $IP"
}

# -------------------------------------------------------
# Création des VMs
# Note : ct-vpn (100) est un conteneur LXC, à créer manuellement
# -------------------------------------------------------
# VMID  Nom               vCPU  RAM    Disque  IP
create_vm 101 "vm-client"     2   4096   60     "192.168.1.211"
create_vm 102 "vm-dc"         2   4096   60     "192.168.1.222"
create_vm 103 "vm-supervision" 2  4096   40     "192.168.1.224"
create_vm 104 "vm-erp"        4   8192   60     "192.168.1.221"
create_vm 105 "vm-nas"        2   4096   40     "192.168.1.219"
create_vm 107 "vm-web"        2   4096   40     "192.168.1.223"

# vm-clone : template de base sans IP fixe
create_vm 106 "vm-clone"      1   2048   20     "dhcp"

# Disque données séparé pour vm-nas (CAO)
echo "--- Ajout disque données 500 Go sur vm-nas (105) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/105/config \
    --scsi1 "${STORAGE_POOL}:500"

# Disque données séparé pour vm-erp (PostgreSQL)
echo "--- Ajout disque données 100 Go sur vm-erp (104) ---"
pvesh create /nodes/$PROXMOX_NODE/qemu/104/config \
    --scsi1 "${STORAGE_POOL}:100"

echo ""
echo "=== Création terminée ==="
echo "Démarrer les VMs manuellement depuis l'interface Proxmox"
echo "puis installer Debian 12 via ISO ou cloud-init."
echo ""
echo "Ordre de démarrage recommandé : vm-dc (102) → vm-nas (105) → vm-erp (104) → vm-web (107) → vm-supervision (103) → ct-vpn (100)"
