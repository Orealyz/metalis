# 04 — Limites et compromis — METALIS

## Limites liées à l'environnement local

### Nœud unique

L'infrastructure repose sur un seul hôte Proxmox. Si le matériel physique tombe en panne, tous les services sont indisponibles simultanément. En production réelle, on déploierait un cluster Proxmox de 2 ou 3 nœuds avec migration automatique des VMs.

### Pas de redondance réseau

Un seul switch et une seule box internet. La coupure internet rend le site e-commerce inaccessible et bloque la messagerie Microsoft 365. Une liaison 4G de secours (failover) serait pertinente pour METALIS compte tenu de sa dépendance à l'e-commerce.

### Wi-Fi atelier

Le sujet mentionne un Wi-Fi instable. La virtualisation ne règle pas ce problème physique. La recommandation est de passer les postes CNC et douchettes en filaire (Ethernet), et de ne garder le Wi-Fi que pour les tablettes. Ce point est hors périmètre du projet mais doit être signalé au client.

### Performances SolidWorks

SolidWorks est gourmand en ressources graphiques. L'accès aux fichiers CAO via Samba réseau sera plus lent qu'un NAS local si la bande passante réseau interne est insuffisante. On recommande un réseau interne en 1 Gbps minimum (câblé).

### Test du VPN limité au réseau de l'établissement

L'infrastructure de démonstration est déployée sur le réseau interne d'Ynov (192.168.1.0/24), qui n'est pas accessible depuis l'extérieur. Le VPN WireGuard (ct-vpn) a donc été testé et validé depuis l'intérieur du réseau de l'établissement, en utilisant l'IP interne du conteneur comme Endpoint dans les configurations clients.

En conditions réelles chez METALIS, l'Endpoint serait l'IP publique de la box/routeur de l'entreprise, avec un port forwarding du port UDP 51821 configuré sur ce routeur vers l'IP interne de ct-vpn. Ce mécanisme est strictement identique en pratique (même protocole, même configuration côté serveur) — seul l'endpoint changerait dans les fichiers de configuration distribués aux commerciaux.

Cette limite est purement liée à l'environnement de test (pas de contrôle sur le NAT/firewall de l'établissement pour ouvrir un port vers l'extérieur) et ne remet pas en cause la validité de la solution technique : le tunnel WireGuard fonctionne, l'authentification par clés est opérationnelle, et le routage vers le réseau interne (192.168.1.0/24) a été vérifié avec succès.

---

## Compromis techniques réalisés

| Compromis | Raison | Alternative en contexte réel |
|---|---|---|
| VMs Windows sans licence KMS | Licences d'évaluation pour la démo | Licences OEM ou volume en production |
| Sauvegarde cloud optionnelle | Budget limité | Proxmox Backup Server + stockage objet S3 |
| VPN WireGuard auto-hébergé | Pas de budget UTM | Firewall UTM (pfSense, OPNsense) avec VPN managé |
| VPN testé en réseau interne uniquement | Pas de contrôle sur le NAT de l'établissement | Port forwarding UDP 51821 sur la box METALIS avec IP publique réelle |
| Un seul nœud Proxmox | Contrainte matérielle | Cluster 2 nœuds minimum |

---

## Ce que l'on ferait différemment en production réelle

1. **Cluster Proxmox 2 nœuds** avec stockage partagé (Ceph ou NFS) pour la haute disponibilité des VMs
2. **Proxmox Backup Server** sur un NAS dédié avec rétention longue (30 jours)
3. **Firewall UTM** (OPNsense ou pfSense) en VM ou boîtier dédié pour le filtrage inter-VLAN et le VPN
4. **Supervision avancée** : Netdata ou Zabbix en remplacement/complément de Prometheus + Grafana
5. **Intégration AD/Odoo** : authentification SSO pour les utilisateurs (éviter plusieurs mots de passe)
6. **CDN** devant WooCommerce pour absorber les pics de trafic lors des campagnes promo
7. **Accès prestataire CNC** via une solution PAM (Privileged Access Management) avec enregistrement de session

---

## Évolutions envisagées

- **Court terme** : ajouter un second disque en RAID logiciel (mdadm) pour protéger le stockage des données CAO
- **Moyen terme** : migrer WooCommerce vers un hébergement cloud managé (moins de maintenance)
- **Long terme** : second site ou synchronisation cloud pour les sauvegardes (METALIS n'a qu'un seul site physique actuellement)
