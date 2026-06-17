# 03 — Continuité de service — METALIS

## Contexte

La direction de METALIS a posé la question clé : *"Que se passe-t-il si tout s'arrête un vendredi après-midi ?"*

La virtualisation ne suffit pas à elle seule à répondre : il faut une stratégie de sauvegarde, des procédures claires et des tests de restauration.

## Stratégie de sauvegarde

### Règle 3-2-1 adaptée au contexte

| Règle | Application chez METALIS |
|---|---|
| **3** copies des données | Données live sur Proxmox + snapshot Proxmox + copie externe |
| **2** supports différents | SSD interne Proxmox + disque externe ou NAS dédié sauvegarde |
| **1** copie hors site | Copie mensuelle sur un stockage cloud (ex. Backblaze B2) |

> La copie cloud est optionnelle à court terme compte tenu du budget, mais fortement recommandée pour les fichiers CAO critiques.

### Planification des snapshots

| VM | Fréquence snapshot | Rétention | Justification |
|---|---|---|---|
| vm-dc | Hebdomadaire | 4 semaines | Changements rares (AD) |
| vm-nas | Quotidienne | 7 jours | Fichiers CAO modifiés fréquemment |
| vm-erp | Quotidienne | 7 jours | Base Odoo critique |
| vm-web | Hebdomadaire | 4 semaines | Contenu moins critique |

Les snapshots sont configurés via le planificateur Proxmox (Datacenter > Backup).

### Sauvegarde des données applicatives

En complément des snapshots VM, on exporte les données applicatives :

```bash
# Sauvegarde PostgreSQL (Odoo) — quotidienne via cron
0 2 * * * pg_dump -U odoo odoo > /backup/odoo_$(date +%Y%m%d).sql

# Sauvegarde des partages Samba (CAO) — quotidienne
0 3 * * * rsync -av /srv/samba/cao/ /backup/cao/
```

## Points de défaillance identifiés

| Point de défaillance | Impact | Mitigation |
|---|---|---|
| Panne du nœud Proxmox | Tous les services indisponibles | Snapshot + procédure de redémarrage rapide documentée |
| Corruption vm-erp | ERP inaccessible | Snapshot quotidien, restauration < 30 min |
| Saturation disque vm-nas | Accès CAO bloqué | Alertes Proxmox sur l'espace disque, volume séparé |
| Coupure réseau (Wi-Fi atelier) | Tablettes/douchettes hors ligne | VLAN atelier sur réseau filaire prioritaire |
| Accès internet coupé | E-commerce inaccessible, pas d'e-mail | Hors périmètre VM ; prévoir 4G de secours |

## Scénarios d'incident et procédures de reprise

### Scénario 1 — Corruption de la VM ERP (cas le plus probable)

**Symptôme :** Odoo ne répond plus, erreur PostgreSQL au démarrage.

**Procédure :**

```
1. Se connecter à l'interface Proxmox (https://proxmox:8006)
2. Arrêter vm-erp (Menu VM > Shutdown)
3. Aller dans "Snapshots" de vm-erp
4. Sélectionner le dernier snapshot quotidien valide
5. Cliquer "Rollback"
6. Démarrer vm-erp
7. Vérifier que Odoo répond (http://192.168.30.30:8069)
8. Prévenir les utilisateurs de la perte de données depuis le dernier snapshot
```

**Temps de restauration estimé : 15 à 30 minutes**

---

### Scénario 2 — Perte des fichiers CAO récents

**Symptôme :** Un fichier SolidWorks a été écrasé ou supprimé par erreur.

**Procédure :**

```
1. Identifier la date du fichier perdu
2. Sur vm-nas, naviguer dans /backup/cao/
3. Retrouver la version du jour J-1 ou J-2
4. Copier le fichier vers /srv/samba/cao/
5. Vérifier l'accès depuis un poste client
```

**Temps de restauration estimé : 5 à 10 minutes**

---

### Scénario 3 — Redémarrage complet après panne matérielle

**Symptôme :** Le mini-PC hôte Proxmox ne répond plus.

**Procédure :**

```
1. Redémarrer physiquement le mini-PC
2. Proxmox démarre automatiquement (service systemd)
3. Les VMs configurées en "Start at boot" redémarrent automatiquement
   (vm-dc, vm-nas, vm-erp)
4. Vérifier l'état des VMs dans l'interface web
5. Si une VM ne démarre pas, consulter les logs Proxmox
   (Datacenter > Node > Syslog)
```

**Temps de reprise estimé : 10 à 20 minutes (démarrage Proxmox + VMs)**

## Configuration recommandée dans Proxmox

```
# Ordre de démarrage des VMs (Proxmox > Options > Start/Shutdown Order)
vm-dc  : ordre 1, délai 60s  (AD doit démarrer en premier)
vm-nas : ordre 2, délai 30s
vm-erp : ordre 3, délai 30s
vm-web : ordre 4, délai 0s
```

## Tests de restauration

Un test de restauration doit être réalisé **une fois par mois** :

- Restaurer vm-erp depuis un snapshot sur une VM temporaire
- Vérifier que l'accès Odoo fonctionne
- Vérifier qu'un fichier CAO récent est bien présent dans la sauvegarde
- Consigner le résultat dans un fichier `tests-restauration.md`
