# Lab 04 · Plan de capacité

> Exercice 4.1 · Inventaire de l'hyperviseur et plan de capacité  
> BlueHarbor · WEB01 FreeBSD 15.1 · VMware Workstation Pro

## 1. Hôte

| Élément | Valeur |
|---|---|
| Modèle CPU | AMD Ryzen 5 5500U with Radeon Graphics |
| Cœurs physiques | 6 |
| Threads logiques | 12 |
| RAM totale | 15,4 GB |
| Hyperviseur | VMware Workstation Pro (type 2) |
| Système d'exploitation hôte | Windows 10 |

## 2. Inventaire des VM

| VM | Rôle | vCPU | RAM (MB) | Disque (GB) | État |
|---|---|---:|---:|---:|---|
| Windows Server 2022 | Contrôleur de domaine, DNS (nom DC01 à confirmer) | 2 | 4096 | 60* | Arrêtée |
| WEB01 | Serveur durci (FreeBSD 15.1) | 2 | 2048 | 25* | Arrêtée |
| WEB02 | Clone lié de WEB01 (Lab 04) | 1* | 1024* | 25* | À créer |

\* Valeurs de disque et paramètres prévus pour WEB02 tirés du cahier ; à confirmer par relevé sur la VM. La taille d'un disque lié ne correspond pas nécessairement à l'espace réellement occupé sur l'hôte.

## 3. Ratios de capacité

### VM actuellement inventoriées

- Surcompromis vCPU = somme des vCPU / threads logiques = (2 + 2) / 12 = **0,33 (33,3 %)**.
- Engagement RAM = (RAM des VM + 4 GB pour l'hôte) / RAM totale = (6 + 4) / 15,4 = **0,65 (64,9 %)**.

### Prévision avec WEB02

- Surcompromis vCPU = (2 + 2 + 1) / 12 = **0,42 (41,7 %)**.
- Engagement RAM = (4 + 2 + 1 + 4) / 15,4 = **0,71 (71,4 %)**.

Les 4 GB ajoutés correspondent à la réserve prévue pour Windows, selon la consigne du cahier.

## 4. Analyse

**VM pouvant fonctionner ensemble sans swap :** selon les valeurs prévues, DC01, WEB01 et WEB02 demanderaient 7 GB de RAM. Avec 4 GB réservés à Windows, l'engagement calculé serait de 11/15,4 GB, soit 71,4 %. Cette estimation laisse environ 4,4 GB de marge. Elle ne garantit pas l'absence de swap : la charge réelle des VM et des applications de l'hôte doit être vérifiée pendant leur fonctionnement.

**Ressource à augmenter en premier :** la RAM est la première ressource à surveiller, car son engagement prévisionnel est de 71,4 %, contre 41,7 % pour les threads CPU. Avant un achat, vérifier la mémoire réellement disponible et l'activité de swap lorsque les VM prévues tournent ensemble.

## 5. Conclusion

Le calcul prévisionnel montre que les trois VM pourraient tenir dans la RAM de l'hôte selon les allocations indiquées, sous réserve de vérifier leur charge réelle. La RAM est le facteur le plus contraignant dans ce scénario.
