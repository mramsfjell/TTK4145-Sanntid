# Reasons for concurrency and parallelism


To complete this exercise you will have to use git. Create one or several commits that adds answers to the following questions and push it to your groups repository to complete the task.

When answering the questions, remember to use all the resources at your disposal. Asking the internet isn't a form of "cheating", it's a way of learning.

 ### What is concurrency? What is parallelism? What's the difference?
 Concurrency happens when several copies of the same program runs at the same time, but the copies communicate with
 each other during the executions. Often only one machine is used, i.e. the instruction code for the program is loaded
 into the memory only once, but the execution may have several threads. Each thread follows its own control flow, but may
 make decisions based on the other threads.

 Parallellism is multiple copies of the same program run at the same time but on different data, e.g. GPU or an search engine.
 Several cores is a keyword.
 

 ### Why have machines become increasingly multicore in the past decade?
 More software programs are multithreaded. The power consumption becomes smaller, the cores take less space etc.
 

 ### What kinds of problems motivates the need for concurrent execution?
 (Or phrased differently: What problems do concurrency help in solving?)
 Concurrency is the ability for a part of an algorithm or a problem to be executed in partial order, without affecting
 the final outcome. Concurrency allows for parallell execution in multiprocessor or multicore systems.
 

 ### Does creating concurrent programs make the programmer's life easier? Harder? Maybe both?
 (Come back to this after you have worked on part 4 of this exercise)
 > *Your answer here*
 

 ### What are the differences between processes, threads, green threads, and coroutines?
 > *Your answer here*
 

 ### Which one of these do `pthread_create()` (C/POSIX), `threading.Thread()` (Python), `go` (Go) create?
 > *Your answer here*
 

 ### How does pythons Global Interpreter Lock (GIL) influence the way a python Thread behaves?
 > *Your answer here*
 

 ### With this in mind: What is the workaround for the GIL (Hint: it's another module)?
 > *Your answer here*
 

 ### What does `func GOMAXPROCS(n int) int` change? 
 > *Your answer here*
