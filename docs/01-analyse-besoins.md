# 01 — Analyse des besoins — METALIS

## Situation existante

METALIS est une PME de ~40 personnes travaillant en 2×8. Elle fabrique des pièces métal et bois sur mesure et vend via une boutique en ligne. Le parc informatique n'est pas administré en interne : un prestataire intervient ponctuellement.

### Problèmes identifiés

| Problème | Impact opérationnel |
|---|---|
| Wi-Fi atelier instable | Tablettes bons de fabrication coupées, douchettes inopérantes |
| NAS saturé et lent | Accès aux fichiers CAO (SolidWorks) dégradé, risque de perte |
| ERP Odoo lent aux heures de charge | Saisies ralenties, frustration des équipes |
| Accès distants peu fiables | Commerciaux en télétravail bloqués sur devis/catalogue |
| Panne NAS (année précédente) | Restauration partielle, plusieurs jours de production perdus |
| Pas de politique de sauvegarde | Copies USB et scripts ad hoc, non vérifiés |
| Accès fournisseur CNC non cadré | Risque de sécurité, traçabilité absente |

### Besoins exprimés par la direction

- *"Que se passe-t-il si tout s'arrête un vendredi après-midi ?"* → continuité de production
- Accès fiable aux fichiers CAO depuis l'atelier
- ERP réactif, même en heure de pointe
- Accès sécurisé pour le prestataire CNC
- Sauvegarde automatique et vérifiable

## Reformulation en exigences techniques

### Exigences fonctionnelles

1. **Partage de fichiers** : serveur de fichiers centralisé remplaçant le NAS, accessible depuis l'atelier et les bureaux avec des droits maîtrisés
2. **ERP** : instance Odoo dédiée avec ressources suffisantes (4 vCPU, 8 Go RAM) pour absorber la charge simultanée
3. **Accès distant** : VPN pour les commerciaux et accès restreint pour le prestataire CNC
4. **Web/e-commerce** : WooCommerce isolé sur une VM dédiée, indépendante de l'ERP
5. **Identité** : Active Directory pour la gestion des utilisateurs et des droits d'accès

### Exigences de continuité

1. Snapshots réguliers des VMs critiques (quotidiens)
2. Sauvegarde externalisée ou sur volume distinct (règle 3-2-1 simplifiée)
3. Procédure documentée de restauration testée
4. Isolation des VMs : une panne de la VM web n'affecte pas l'ERP

### Justification de la virtualisation

La virtualisation répond directement aux problèmes de METALIS :

- **Consolidation** : remplace le NAS vieillissant et le serveur Windows Server par des VMs sur un hyperviseur moderne
- **Isolation** : si le site e-commerce tombe (pic de trafic, mise à jour ratée), l'ERP continue de fonctionner
- **Sauvegarde cohérente** : les snapshots Proxmox figent l'état complet d'une VM, ce qu'une copie USB ne peut pas garantir
- **Évolutivité** : ajouter de la RAM ou du CPU à une VM ne nécessite pas de changer de matériel physique
- **Accès distants** : les VMs peuvent exposer des services VPN sans modifier le réseau physique existant

## Logiciels et usages retenus

| Domaine | Outil | VM associée |
|---|---|---|
| Identité / partages | Active Directory + Samba | `vm-dc` |
| Fichiers CAO | Samba sur Debian | `vm-nas` |
| ERP | Odoo 17 | `vm-erp` |
| E-commerce + vitrine | WooCommerce + WordPress | `vm-web` |
| Messagerie | Microsoft 365 (cloud, inchangé) | — |
| Atelier (CNC, étiquettes) | Accès réseau via VLAN dédié | VLAN 20 |
