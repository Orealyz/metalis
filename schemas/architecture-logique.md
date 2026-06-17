                                                                                                                                                                                                                                                                    # Schéma — Architecture logique METALIS

## Diagramme (Mermaid)

```mermaid
graph TD
    subgraph Physique["Hôte physique — Mini-PC / VPS"]
        PVE["Proxmox VE 9.2-1"]

        subgraph VLAN30["VLAN 30 — Serveurs (192.168.30.0/24)"]
            DC["vm-dc\nWindows Server 2022\nActive Directory + DNS\n192.168.30.10"]
            NAS["vm-nas\nDebian 12\nSamba (fichiers CAO)\n192.168.30.20"]
            ERP["vm-erp\nDebian 12\nOdoo 17 + PostgreSQL\n192.168.30.30"]
        end

        subgraph VLAN40["VLAN 40 — DMZ (192.168.40.0/24)"]
            WEB["vm-web\nDebian 12\nWordPress + WooCommerce\n192.168.40.10"]
        end

        subgraph VLAN10["VLAN 10 — Bureaux (192.168.10.0/24)"]
            CLIENT["vm-client\nWindows 10 (test)\n192.168.10.50"]
        end
    end

    subgraph VLAN20["VLAN 20 — Atelier (192.168.20.0/24)"]
        CNC["Machines CNC"]
        TAB["Tablettes bons de fab."]
        ETI["Imprimantes étiquettes"]
    end

    subgraph Externe
        M365["Microsoft 365\n(cloud)"]
        VPN_CT["Commerciaux\ntélétravail\n(WireGuard)"]
        PREST["Prestataire CNC\n(VPN restreint)"]
    end

    PVE --> DC
    PVE --> NAS
    PVE --> ERP
    PVE --> WEB
    PVE --> CLIENT

    DC -- "Authentification AD" --> CLIENT
    DC -- "DNS" --> ERP
    NAS -- "Samba" --> CLIENT
    ERP -- "API Odoo" --> WEB

    VPN_CT -- "WireGuard UDP 51820" --> ERP
    PREST -- "VPN VLAN 20 uniquement" --> CNC
    CLIENT -- "Port 8069" --> ERP
    CLIENT -- "SMB" --> NAS
```

## Représentation textuelle

```
┌─────────────────────────────────────────────────────────────┐
│                    Hôte Proxmox VE                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   vm-dc      │  │   vm-nas     │  │   vm-erp     │      │
│  │ Win Srv 2022 │  │  Debian 12   │  │  Debian 12   │      │
│  │ AD + DNS     │  │ Samba / CAO  │  │ Odoo + PgSQL │      │
│  │ .30.10       │  │ .30.20       │  │ .30.30       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         VLAN 30 — Serveurs (192.168.30.0/24)                │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │   vm-web     │  │  vm-client   │                         │
│  │  Debian 12   │  │  Windows 10  │                         │
│  │ WP+WooComm.  │  │  (test)      │                         │
│  │ .40.10       │  │ .10.50       │                         │
│  └──────────────┘  └──────────────┘                         │
│   VLAN 40 — DMZ        VLAN 10 — Bureaux                    │
└─────────────────────────────────────────────────────────────┘

VLAN 20 — Atelier (physique)
  ├── Machines CNC (192.168.20.x)
  ├── Tablettes bons de fabrication
  └── Imprimantes étiquettes, douchettes

Accès externes :
  ├── Commerciaux télétravail → VPN WireGuard → vm-erp
  ├── Prestataire CNC → VPN restreint → VLAN 20 uniquement
  └── Clients web → Internet → vm-web (DMZ)
```
