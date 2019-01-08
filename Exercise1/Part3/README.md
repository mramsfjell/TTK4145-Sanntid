# Reasons for concurrency and parallelism


To complete this exercise you will have to use git. Create one or several commits that adds answers to the following questions and push it to your groups repository to complete the task.

When answering the questions, remember to use all the resources at your disposal. Asking the internet isn't a form of "cheating", it's a way of learning.

 ### What is concurrency? What is parallelism? What's the difference?
>Concurrency happens when several copies of the same program runs at the same time, but the copies communicate with
 each other during the executions. Often only one machine is used, i.e. the instruction code for the program is loaded
 into the memory only once, but the execution may have several threads. Each thread follows its own control flow, but may
 make decisions based on the other threads.

>Parallellism is multiple copies of the same program run at the same time but on different data, e.g. GPU or an search engine.
 Several cores is a keyword.
 

 ### Why have machines become increasingly multicore in the past decade?
 More software programs are multithreaded. The power consumption becomes smaller, the cores take less space etc.
 

 ### What kinds of problems motivates the need for concurrent execution?
 (Or phrased differently: What problems do concurrency help in solving?)
 Concurrency is the ability for a part of an algorithm or a problem to be executed in partial order, without affecting
 the final outcome. Concurrency allows for parallell execution in multiprocessor or multicore systems.
 

 ### Does creating concurrent programs make the programmer's life easier? Harder? Maybe both?
 (Come back to this after you have worked on part 4 of this exercise)
 If handled correctly, concurrent programs are an advantage if we have several cores available.
 It may also make a programmer's life a living hell...
 

 ### What are the differences between processes, threads, green threads, and coroutines?
 Processes run in separate memory spaces, while threads run in a shared memory space.

 A green thread is scheduled by a virtual machine.

 A coroutine is a control structure where the flow control is passed between two different routines without returning.
 Only one coroutine is running at any given time, even in multicore systems.
 

 ### Which one of these do `pthread_create()` (C/POSIX), `threading.Thread()` (Python), `go` (Go) create?
 They create a new thread in C and Python, and a goroutine (lightweight thread -- requires less processing time)
 in Go, respectively.
 

 ### How does pythons Global Interpreter Lock (GIL) influence the way a python Thread behaves?
 GIL is a Mutex (Mutual Exclusion) that protects access to objects, and thus preventing multiple threads from
 executing Python bytecodes at once. In practice preventing threads from running in parallell in Python.
 

 ### With this in mind: What is the workaround for the GIL (Hint: it's another module)?
 Using the threading module from Python
 

 ### What does `func GOMAXPROCS(n int) int` change? 
 GOMAXPROCS limits the number of system threads that can execute Go code simultaneously.
