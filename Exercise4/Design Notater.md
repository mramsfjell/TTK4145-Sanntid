# Designnotater
## Moduler
- Controller:
    - Snakker med hverandre, sin egen respektive heis, setter hall call-knapper, cab call-knapper
    - Opererer med en (per nå ubestemt) kostfunksjon:
        - Ved en ny bestilling fra hall call-panel 'i', vil controller 'i' kalkulerer sin egen kostfunksjon, og samtidig få kostfunksjon fra de '0-n' andre controllerne. Vil på det grunnlaget bestemme hvem som til slutt får hall call-bestillingen (eksternordren).
        - Ved cab call-bestilling (internordre), vil alle andre heiser ha uendelig kost.
    - 
    


- Lift: 
    - Tar seg av etasjeindikatorer, men ikke ordrelys etc.

- Buttons


- Orders

## Ordrebehandling


## Kommunikasjon
Alle-til-alle-kommunikasjon. Alle controllerne vet hva de andre har av ordre, inkludert internordre.