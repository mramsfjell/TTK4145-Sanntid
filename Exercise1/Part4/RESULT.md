### Result
 Observe that i after some runs is 0, other times it's either a positive or a negative number.
 It's no repetitive pattern.

 The reason being that i is a shared resource between the incrementing and decrementing functions.
 i could be read and modified by one of the functions, then being read from memory by the other function
 before the former has written to the memory. This is a result of concurrency.