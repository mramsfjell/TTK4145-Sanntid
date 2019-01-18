# Mutex and Channel basics

### What is an atomic operation?
> Atomic operation is a sequence which needs to complete without interruption.
It can also be considered to be instantaneous.

### What is a semaphore?
> Et flagg som skal gi beskjed om at en ressurs er i bruk. En semafor er mer generell, er en datastruktur
og ikke bare et bin�rt flagg.

### What is a mutex?
> Mutual Exclusion er et objekt som muliggj�r at flere tr�der kan ha tilgang til en ressurs,
men Mutex f�rer til at kun en tr�d kan bruke ressursen om gangen.

### What is the difference between a mutex and a binary semaphore?
> Bin�r semafor er et bin�rt flagg, som signalerer at en ressurs er i bruk. Mutex l�ser objektet, semaforen sier i fra
at objektet er opptatt.

### What is a critical section?
> Delen av programmet/koden som kan f�re til et sanntidsproblem. En m�te � beskrive en kodefnutt.

### What is the difference between race conditions and data races?
 > En race condition g�r p� rekkef�lgen av operasjoner, mens data race g�r ut p� at to minneaksesser
pr�ver � aksessere samme minnelokasjon.

### List some advantages of using message passing over lock-based synchronization primitives.
> N�r man sender meldinger, kan man vite at man har riktig informasjon. Ulempen er at det er vanskelig � si noe om
timing p� n�r operasjoner er ferdig.

### List some advantages of using lock-based synchronization primitives over message passing.
> Enkelt � si noe om n�r en operasjon er ferdig, tradeoff mellom timing korrekthet
hva gjelder informasjonen som blir sendt.
