# Mutex and Channel basics

### What is an atomic operation?
> Atomic operation is a sequence which needs to complete without interruption.
It can also be considered to be instantaneous.

### What is a semaphore?
> Et flagg som skal gi beskjed om at en ressurs er i bruk. En semafor er mer generell, er en datastruktur
og ikke bare et binært flagg.

### What is a mutex?
> Mutual Exclusion er et objekt som muliggjør at flere tråder kan ha tilgang til en ressurs,
men Mutex fører til at kun en tråd kan bruke ressursen om gangen.

### What is the difference between a mutex and a binary semaphore?
> Binær semafor er et binært flagg, som signalerer at en ressurs er i bruk. Mutex låser objektet, semaforen sier i fra
at objektet er opptatt.

### What is a critical section?
> Delen av programmet/koden som kan føre til et sanntidsproblem. En måte å beskrive en kodefnutt.

### What is the difference between race conditions and data races?
 > En race condition går på rekkefølgen av operasjoner, mens data race går ut på at to minneaksesser
prøver å aksessere samme minnelokasjon.

### List some advantages of using message passing over lock-based synchronization primitives.
> Når man sender meldinger, kan man vite at man har riktig informasjon. Ulempen er at det er vanskelig å si noe om
timing på når operasjoner er ferdig.

### List some advantages of using lock-based synchronization primitives over message passing.
> Enkelt å si noe om når en operasjon er ferdig, tradeoff mellom timing korrekthet
hva gjelder informasjonen som blir sendt.
