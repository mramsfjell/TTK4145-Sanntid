# Designnotater - førsteutkast
## Moduler
- Controller:
    - Snakker med hverandre, sin egen respektive heis, setter hall call-lys, cab call-lys
    - Opererer med en (per nå ubestemt) kostfunksjon:
        - Ved en ny bestilling fra hall call-panel 'i', vil controller 'i' kalkulerer sin egen kostfunksjon, og samtidig få kostfunksjon fra de '0-n' andre controllerne. Vil på det grunnlaget bestemme hvem som til slutt får hall call-bestillingen (eksternordren).
        - Ved cab call-bestilling (internordre), vil alle andre heiser ha uendelig kost.
    - 
    


- Lift: 
    - Tar seg av etasjeindikatorer, men ikke ordrelys etc.
    - FSM:

    ![FSM Draft](https://github.com/simenkrantz/TTK4145-Sanntid/blob/master/Exercise4/fsm_draft.png)

- Buttons


- Orders

## Kommunikasjon
Controllerne sender ut informasjon med et gitt intervall, f.eks. hvert halve sekund e.l. Alle controllerne vet hva de andre har av ordre, inkludert internordre -- dette for 

## Nettverksfeil eller powerloss
Ved nettverksfeil, vil soloheisen slette alle 