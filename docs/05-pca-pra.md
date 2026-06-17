# 05 — PCA / PRA — METALIS

## Définitions

- **PCA** (Plan de Continuité d'Activité) : maintenir l'activité métier pendant un incident
- **PRA** (Plan de Reprise d'Activité) : remettre en service l'infrastructure après un sinistre

Fenêtre de tolérance client : **20h–4h** (hors plage de production 2×8)

---

## RTO / RPO par service

| Service | VM | RTO cible | RPO cible |
|---|---|---|---|
| Fichiers CAO | vm-nas | **30 min** | 24h |
| Active Directory | vm-dc | 1h | 7 jours |
| ERP Odoo | vm-erp | 2h | 24h |
| Site e-commerce | vm-web | 4h | 7 jours |
| VPN | ct-vpn | 4h | N/A |

> vm-nas est le service **le plus critique** : le client a déjà subi une panne NAS avec perte de données. C'est le seul qui bloque complètement la production.

---

## Mode dégradé

| Service indisponible | Action immédiate |
|---|---|
| vm-nas | Accéder aux fichiers en lecture sur le disque de sauvegarde rsync |
| vm-erp | Prise de commandes en mode manuel, ressaisie Odoo après reprise |
| vm-dc | Sessions déjà ouvertes restent actives (cache Windows) ; nouvelles connexions bloquées |
| vm-web | Page de maintenance ; redirection vers commande téléphonique |
| ct-vpn | Pas de mode dégradé requis (service nouvellement créé) |

---

## Procédure de reprise (tous services)

```
1. Identifier le service impacté
2. Tenter un redémarrage simple de la VM / du service
3. Si échec → restaurer le dernier snapshot valide depuis Proxmox
4. Vérifier le bon fonctionnement
5. Informer les utilisateurs
6. Consigner l'incident (cause, durée, actions)
```

### Ordre de démarrage après panne totale du nœud

`vm-dc` → `vm-nas` → `vm-erp` → `vm-web` → `vm-supervision` → `ct-vpn`

---

## Limites

- RTO 30 min sur vm-nas **non encore validé** avec un volume réaliste (4 To, fichiers ~1 Go)
- Pas de redondance matérielle (nœud Proxmox unique)
- Sauvegardes stockées sur le même hôte — un sinistre physique rendrait ce PRA inopérant
- Risque Wi-Fi/CPL atelier (6 000 m², 2 répéteurs) hors périmètre de la virtualisation
