# Designnotater - førsteutkast

**_Legg gjerne til manglende informasjon_**

## Moduler
- `Controller`:
    - Snakker med evt. andre controllere, og tar hånd om bestillinger -- hvilken heis skal ta hvilken ordre.
    - Opererer med en (per nå ubestemt) kostfunksjon:
        - Ved en ny bestilling fra hall call-panel `i`, vil controller `i` kalkulerer sin egen kostfunksjon, og samtidig få kostfunksjon fra de `0-n` andre controllerne. Vil på det grunnlaget bestemme hvem som til slutt får hall call-bestillingen (eksternordren). Dette vil også fungere i spesialtilfellet ved nettverksbrudd og soloheis.
        - Ved cab call-bestilling (internordre), vil alle andre heiser ha uendelig kost.
    - 
    
- `Lift`: 
    - Tar seg kun av etasjeindikatorer, ikke ordrelys etc.
    - FSM:
        - `MOVING`-staten har en `bool dir`-variabel, som husker siste retning heisen hadde.
        - Hvis heisen ikke har noen ordre, hverken cab eller hall call, står den i `IDLE` og venter.
        - Fordel å vite hvor man går fra `INIT`og `DOOR_OPEN`, det er grunnen til at vi ikke har direkte transition fra `MOVING`til `DOOR_OPEN`.

    ![FSM Draft](https://github.com/simenkrantz/TTK4145-Sanntid/blob/master/Exercise4/fsm_draft.png)

- `Buttons`:
    - Snakker med `Lift`-modulen. Tar seg av registrering av ordre og lys i ordreknapper, både cab og hall. Controllerne kan på denne måten dobbeltsjekke at en ordre har blitt bekreftet som en bestilling.


- `Orders`:
    - Generelt er det irrelevant hvor heisen skal ende opp. Når man ankommer en gitt etasje, sjekker heisen om den har en cab call til denne etasjen eller om den har en hall call den skal ta hånd om.
    - Et forslag hva gjelder oppsett av ordre i den felles sendte ordrematrisen, er å ha en timer tilhørende hver ordre. Hvis en ordre ikke fjernes innen f.eks. to eller fem minutter, sendes den enten på ny til den respektive controlleren eller blir redistribuert til en av de andre.

## Kommunikasjon
Controllerne sender ut informasjon med et gitt intervall, f.eks. hvert halve sekund e.l. Alle controllerne vet hva de andre har av ordre, inkludert internordre -- dette som backup ved nettverksfeil eller powerloss.

En ordrematrise med leserettigheter blir sendt fra alle til alle, men hver controller kan i utgangspunktet bare skrive over sine egne ordre.
- Her vil det være unntak, bl.a. ved feil på en heis.

![Forsøk på kommunikasjon](https://github.com/simenkrantz/TTK4145-Sanntid/blob/master/Exercise4/communication_draft.png)

## Nettverksfeil eller powerloss
Ved nettverksbrudd vil soloheisen ta seg av alle sine ordre, både intern- og eksternordre. Da vil de to heisene som fortsatt snakker sammen redistribuere soloheisens eksternordre, kan da oppleve at samme ordre blir ekspedert to ganger. Vi anser det som et nødvendig onde. Når nettverket er oppe og går igjen, vil soloheisen pushe sin ordreliste til de to andre, og be om å få oppdatert de to andre listene hos seg selv.

Ved powerloss vil den respektive heisen gå tilbake til `INIT`. Denne heisen vil da spørre om å få sin egen ordreliste fra de to andre, og til forskjell fra oppstart vil det mest sannsynlig komme en ikke-tom liste i retur.


## Config-fil og oppstart
Ved oppstart vil hver heis be om å få oppdatert sin egen ordreliste. Hvis ordrelisten man får er helt tom, kan man anta man er første heis som er oppe og går.

Config er noe vi må se mer på. Antar at denne ikke er korrupt, og inneholder riktig informasjon.

