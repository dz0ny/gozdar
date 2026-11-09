---
title: "Hlodi: izmerite hlod, Gozdar izračuna ostalo"
description: "Vpišete premer in dolžino, aplikacija izračuna prostornino. Hlodi se razvrstijo po vrstah, skupne količine so v m³, prostorninskih in nasutih metrih."
date: "2026-10-19"
category: "Hlodi"
author: "Janez Troha"
cover: "../../assets/screens/02-logs.webp"
coverAlt: "Zavihek Hlodi: 5 hlodov, skupaj 2,57 m³, razvrščeni po vrstah Bukev in Smreka"
---

Zavihek **Hlodi** nadomesti zvezek in kalkulator. Vpišete premer in dolžino, vse drugo izračuna aplikacija.

## Vnos kot na kalkulatorju

Vrstica za hitri vnos je ves čas na vrhu seznama. Vpišete premer v centimetrih in dolžino v metrih, tapnete **+** in hlod je zabeležen. Dolžina ostane za naslednji hlod, izbriše se samo premer, ker se pri hlodih iste dolžine spreminja predvsem premer.

Prostornina se izračuna po formuli

> V = π × (d / 200)² × L

kjer je d premer v centimetrih in L dolžina v metrih. Hlod s premerom 45 cm in dolžino 4,5 m ima tako 0,716 m³.

## Po drevesnih vrstah

Vsak hlod dobi drevesno vrsto. Privzete so smreka, bukev in jelka, svoje dodate v meniju ⋮ pod **Upravljanje vrst**. Ko so na seznamu vsaj dve vrsti, se hlodi sami razvrstijo po vrstah, vsaka skupina pa pokaže število hlodov in skupno prostornino, na primer »3 hlodov • 1,25 m³«.

## m³, PRM in NM

Skupna količina je prikazana v kubičnih metrih in preračunana v:

- **prostorninske metre (PRM)** za zložena drva: m³ ÷ 0,65,
- **nasute metre (NM)** za sekance: m³ ÷ 0,40.

Oba faktorja lahko spremenite v nastavitvah, če se z odkupovalcem dogovorite drugače.

## Shrani hlode

Z gumbom **Shrani hlode** seznam shranite kot imenovan sklop z lokacijo. Hlod lahko dodate tudi z dolgim pritiskom na karto, kjer dobi GPS koordinate in se poveže s parcelo. Na karti so hlodi označeni rjavo, da jih kasneje najdete. Celoten sklop izvozite v Excel.
