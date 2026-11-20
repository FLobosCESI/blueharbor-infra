# Lab 04 · Plan de capacité

> Exercice 4.1 · Inventaire de l'hyperviseur et plan de capacité
> BlueHarbor · WEB01 FreeBSD 15.1 · VMware Workstation Pro
> Statut : structure prête, valeurs d'hôte à relever (voir section 1).

## 1. Hôte

| Élément | Valeur |
|---|---|
| Modèle CPU | |
| Cœurs physiques | |
| Threads logiques | |
| RAM totale | GB |
| Hyperviseur | VMware Workstation Pro |
| Système d'exploitation hôte | Windows 10 |

Relevé :

```powershell
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
```

## 2. Inventaire des VM

Les valeurs des colonnes vCPU, RAM et Disque proviennent de la table de référence du cahier
(§ Reference data). Elles doivent être confirmées sur le fichier `.vmx` de chaque machine
avant d'être considérées comme mesurées.

| VM | Rôle | vCPU | RAM (MB) | Disque (GB) | État |
|---|---|---|---|---|---|
| DC01 | Contrôleur de domaine, DNS | 2 | 4096 | 60 | |
| WEB01 | Serveur web durci (FreeBSD 15.1) | 2 | 2048 | 25 | |
| WEB02 | Clone lié de WEB01 (Lab 04) | 1 | 1024 | 25 | à créer |

Relevé :

```powershell
$root = "$env:USERPROFILE\Documents\Virtual Machines"
Get-ChildItem $root -Recurse -Filter *.vmx | ForEach-Object {
  $c = Get-Content $_.FullName
  "{0} | {1} | {2}" -f $_.Directory.Name,
    ($c | Select-String '^numvcpus').Line,
    ($c | Select-String '^memsize').Line
}
```

## 3. Ratios

- Surcompromis vCPU = Σ vCPU / threads logiques = (2 + 2 + 1) / … = … / … = …
- Engagement RAM = (Σ RAM VM + 4 GB) / RAM hôte = (4 + 2 + 1 + 4) / … = 11 / … = …

Les 4 GB ajoutés représentent le système d'exploitation hôte et ne sont pas comptés
dans la somme des VM.

## 4. Analyse

**Quelles VM peuvent tourner ensemble sans swapper :**

**Ce qu'il faudrait acheter en premier pour faire tourner toutes les VM :**

## 5. Conclusion

Le plan de capacité fixe la limite haute du laboratoire : au-delà, l'hôte swappe et les
mesures de l'exercice 4.3 deviennent non reproductibles.
