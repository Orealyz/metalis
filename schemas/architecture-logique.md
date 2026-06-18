                                                                                                                                                                                                                                                                    # Schéma — Architecture logique METALIS

## Diagramme (Mermaid)

```mermaid
graph TD
    subgraph Physique["Hôte physique — Mini-PC / VPS"]
        PVE["Proxmox VE"]

        subgraph Réseau["Réseau 10.33.81.0/24"]
            VPN["ct-vpn [CT]\nDebian 12\nWireGuard VPN\n10.33.81.208"]
            DC["vm-dc\nWindows Server 2022\nActive Directory + DNS\n10.33.81.222"]
            NAS["vm-nas\nDebian 12\nSamba (fichiers CAO)\n10.33.81.219"]
            ERP["vm-erp\nDebian 12\nOdoo 17 + PostgreSQL\n10.33.81.221"]
            WEB["vm-web\nDebian 12\nWordPress + WooCommerce\n10.33.81.223"]
            SUP["vm-supervision\nDebian 12\nPrometheus + Grafana + Loki\n10.33.81.224"]
            CLIENT["vm-client\nWindows 10 (test)\n10.33.81.211"]
            CLONE["vm-clone\nDebian 12\nTemplate de base"]
        end
    end

    subgraph VLAN20["VLAN 20 — Atelier (physique)"]
        CNC["Machines CNC"]
        TAB["Tablettes bons de fab."]
        ETI["Imprimantes étiquettes"]
    end

    subgraph Externe
        M365["Microsoft 365\n(cloud)"]
        VPN_CT["Commerciaux\ntélétravail\n(WireGuard)"]
        PREST["Prestataire CNC\n(VPN restreint)"]
        TELEGRAM["Telegram\n(alertes)"]
    end

    PVE --> VPN
    PVE --> DC
    PVE --> NAS
    PVE --> ERP
    PVE --> WEB
    PVE --> SUP
    PVE --> CLIENT
    PVE --> CLONE

    DC -- "Authentification AD" --> CLIENT
    DC -- "DNS" --> ERP
    NAS -- "Samba" --> CLIENT
    ERP -- "API Odoo" --> WEB

    VPN_CT -- "WireGuard UDP 51820" --> VPN
    PREST -- "VPN restreint" --> VPN
    VPN -- "tunnel" --> DC
    VPN -- "tunnel" --> ERP
    PREST -- "via VPN" --> CNC
    CLIENT -- "Port 8069" --> ERP
    CLIENT -- "SMB" --> NAS

    SUP -- "alertes" --> TELEGRAM
```

## Représentation textuelle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Hôte Proxmox VE                                 │
│                      Réseau : 10.33.81.0/24                             │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │  [CT] ct-vpn │  │   vm-dc      │  │   vm-nas     │                  │
│  │  Debian 12   │  │ Win Srv 2022 │  │  Debian 12   │                  │
│  │  WireGuard   │  │  AD + DNS    │  │ Samba / CAO  │                  │
│  │ .81.208      │  │ .81.222      │  │ .81.219      │                  │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │   vm-erp     │  │   vm-web     │  │ vm-supervision│                 │
│  │  Debian 12   │  │  Debian 12   │  │  Debian 12   │                  │
│  │ Odoo + PgSQL │  │ WP+WooComm.  │  │ Prom+Graf+Loki│                 │
│  │ .81.221      │  │ .81.223      │  │ .81.224      │                  │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐                                     │
│  │  vm-client   │  │  vm-clone    │                                     │
│  │  Windows 10  │  │  Debian 12   │                                     │
│  │  (test)      │  │  (template)  │                                     │
│  │ .81.211      │  │      —       │                                     │
│  └──────────────┘  └──────────────┘                                     │
└─────────────────────────────────────────────────────────────────────────┘

VLAN 20 — Atelier (physique)
  ├── Machines CNC
  ├── Tablettes bons de fabrication
  └── Imprimantes étiquettes, douchettes

Accès externes :
  ├── Commerciaux télétravail → WireGuard UDP 51820 → ct-vpn (10.33.81.208)
  ├── Prestataire CNC → VPN restreint → ct-vpn → VLAN 20 uniquement
  ├── Clients web → Internet → vm-web (10.33.81.223)
  └── Alertes supervision → vm-supervision → Telegram
```
