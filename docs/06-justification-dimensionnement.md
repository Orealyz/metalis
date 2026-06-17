# 06 — Justification du dimensionnement des VMs — METALIS

Chaque VM est dimensionnée à partir de deux sources : les chiffres réels de l'entretien client (volumétrie, charge, usages) et les recommandations officielles des éditeurs, avec une marge de sécurité raisonnable.

## vm-dc — 2 vCPU / 4 Go / 60 Go

Microsoft recommande un minimum de 1 vCPU / 512 Mo pour un AD de moins de 100 utilisateurs. Avec 40 comptes chez METALIS, 2 vCPU / 4 Go offre une large marge (x4 à x8), qui couvre aussi le DNS hébergé sur la même VM.

## vm-nas — 2 vCPU / 4 Go / 40 Go OS + 500 Go données

Samba est peu gourmand en CPU (2 vCPU / 4 Go suffit largement pour une dizaine d'accès simultanés). Le stockage est le point sensible : le client déclare **4 To** de fichiers CAO en croissance "exponentielle". Les 500 Go ici sont un dimensionnement de **démonstration** (limite du mini-PC/VPS de lab) — en production il faudrait viser **6 To** (données + marge + sauvegardes locales). Écart assumé et documenté dans [04-limites-compromis.md](./04-limites-compromis.md).

## vm-erp — 4 vCPU / 8 Go / 60 Go + 100 Go données

Odoo recommande 2 vCPU / 4 Go pour une charge modérée (10-30 utilisateurs). On double ce minimum car le client a explicitement signalé des **lenteurs en heure de charge** sur l'ERP actuel, avec un chevauchement des pics production (04h-20h) et e-commerce (08h-17h). Sous-dimensionner reproduirait le problème que le projet doit résoudre.

## vm-web — 2 vCPU / 4 Go / 40 Go

Une stack WordPress/WooCommerce standard tourne avec 1 vCPU / 2 Go. On double ce minimum pour absorber les **pics de campagnes promotionnelles** mentionnés par le client, sans surdimensionner en dehors de ces périodes.

## vm-supervision — 2 vCPU / 4 Go / 40 Go

Prometheus + Grafana + Loki nécessitent environ 1 vCPU / 2 Go pour un parc de moins de 10 nœuds surveillés. On double pour absorber la rétention de logs (Loki) et les requêtes Grafana en temps réel sans dégrader la collecte des métriques.

## ct-vpn — 1 vCPU / 512 Mo / 8 Go

WireGuard est extrêmement léger. Un conteneur LXC avec 1 vCPU / 512 Mo est largement suffisant pour une dizaine de tunnels simultanés. Le choix d'un CT plutôt qu'une VM réduit l'overhead et limite la surface d'attaque exposée sur Internet.

## vm-client — 2 vCPU / 4 Go / 60 Go

Poste de test, dimensionné selon les exigences standard Windows 10. Pas de calcul de charge spécifique : un seul utilisateur, usage de validation technique uniquement.

## Récapitulatif

| VM / CT | vCPU | RAM | Disque | Justification principale |
|---|---|---|---|---|
| vm-dc | 2 | 4 Go | 60 Go | Recommandation Microsoft x4-x8 |
| vm-nas | 2 | 4 Go | 40+500 Go | Volumétrie client réelle (limite lab assumée) |
| vm-erp | 4 | 8 Go | 60+100 Go | Lenteurs déclarées par le client + recommandation Odoo x2 |
| vm-web | 2 | 4 Go | 40 Go | Pics de charge promo déclarés par le client |
| vm-supervision | 2 | 4 Go | 40 Go | Rétention logs Loki + requêtes Grafana temps réel |
| ct-vpn | 1 | 512 Mo | 8 Go | WireGuard léger — CT suffisant, surface d'attaque réduite |
| vm-client | 2 | 4 Go | 60 Go | Usage de test standard |
