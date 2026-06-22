# 03 — Continuité de service — METALIS

La direction a posé la question clé : *"Que se passe-t-il si tout s'arrête un vendredi après-midi ?"*

Fenêtre de tolérance client : **20h–4h** (hors plage de production 2×8).

---

## RTO / RPO par service

| Service | VM | RTO cible | RPO cible |
|---|---|---|---|
| Fichiers CAO | vm-nas | **30 min** | 4h |
| Active Directory | vm-dc | 1h | 7 jours |
| ERP Odoo | vm-erp | 2h | 4h |
| Site e-commerce | vm-web | 4h | 4h |
| VPN | ct-vpn | 4h | N/A |

> vm-nas est le service **le plus critique** : le client a déjà subi une panne NAS avec perte de données. Son indisponibilité bloque toute la production.

---

## Stratégie de sauvegarde

### Règle 3-2-1

| Règle | Application chez METALIS |
|---|---|
| **3** copies | Données live + snapshot Proxmox + copie externe |
| **2** supports | SSD interne Proxmox + disque externe ou NAS dédié |
| **1** copie hors site | Stockage cloud (ex. Backblaze B2) |

### Planification des snapshots

| VM / CT | Fréquence | Rétention |
|---|---|---|
| vm-nas | Toutes les 4h | 7 jours |
| vm-erp | Toutes les 4h | 7 jours |
| vm-dc | Hebdomadaire | 4 semaines |
| vm-web | Toutes les 4h | 7 jours |
| vm-supervision | Hebdomadaire | 4 semaines |
| ct-vpn | Hebdomadaire | 4 semaines |

### Sauvegardes applicatives (cron)

```bash
# PostgreSQL (Odoo) — quotidienne à 2h
0 2 * * * pg_dump -U odoo odoo > /backup/odoo_$(date +%Y%m%d).sql

# Partages Samba (CAO) — quotidienne à 3h
0 3 * * * rsync -av /srv/samba/cao/ /backup/cao/
```

---

## Mode dégradé

| Service indisponible | Action immédiate |
|---|---|
| vm-nas | Accéder aux fichiers sur le disque de sauvegarde rsync (lecture seule) |
| vm-erp | Prise de commandes manuelle, ressaisie Odoo après reprise |
| vm-dc | Sessions ouvertes restent actives ; nouvelles connexions bloquées |
| vm-web | Page de maintenance ; redirection vers commande téléphonique |
| ct-vpn | Pas de mode dégradé (service nouvellement créé) |

---

## Procédures de reprise

### Restauration d'une VM (cas général)

```
1. Se connecter à Proxmox (https://<IP_PROXMOX>:8006)
2. Tenter un redémarrage simple de la VM
3. Si échec : arrêter la VM → Snapshots → Rollback sur le dernier snapshot valide
4. Redémarrer la VM et vérifier le service
5. Informer les utilisateurs
6. Consigner l'incident (cause, durée, actions)
```

### Récupération d'un fichier CAO isolé

```
1. Sur vm-nas, naviguer dans /backup/cao/
2. Retrouver la version J-1 ou J-2
3. Copier le fichier vers /srv/samba/cao/
4. Vérifier l'accès depuis un poste client (\\192.168.1.219\CAO)
```

**Temps estimé : 5 à 10 minutes**

### Panne totale du nœud Proxmox

```
1. Redémarrer physiquement le serveur
2. Proxmox démarre automatiquement
3. Les VMs en "Start at boot" redémarrent dans l'ordre ci-dessous
4. Vérifier l'état de chaque service dans l'interface web
```

**Temps estimé : 10 à 20 minutes**

### Ordre de démarrage (Proxmox > VM > Options > Start/Shutdown Order)

```
vm-dc         ordre 1 — délai 60s  (AD et DNS en premier)
vm-nas        ordre 2 — délai 30s
vm-erp        ordre 3 — délai 30s
vm-web        ordre 4 — délai 0s
vm-supervision ordre 5 — délai 0s
ct-vpn        ordre 6 — délai 0s
```

---

## Limites

- RTO 30 min sur vm-nas **non validé en conditions réelles** (4 To, fichiers ~1 Go — à tester en priorité)
- Snapshots stockés sur le même hôte : un sinistre physique rendrait la sauvegarde inopérante
- Pas de redondance matérielle (nœud Proxmox unique)
- Risque Wi-Fi/CPL atelier hors périmètre de la virtualisation — voir [04-limites-compromis.md](./04-limites-compromis.md)
