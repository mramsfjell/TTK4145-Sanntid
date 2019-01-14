// Use `go run foo.go` to run your program

package main

import (
	. "fmt"
	"runtime"
	"time"
)

var i = 0

func incrementing() {
	//TODO: increment i 1000000 times
	for j := 0; j < 1000000; j++ {
		i += 1
	}
}

func decrementing() {
	//TODO: decrement i 1000000 times
	for j := 0; j < 1000000; j++ {
		i -= 1
	}
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())

	/*
	   GOMAXPROCS limits the number of system threads that can execute Go code simultaneously

	   If the argument to GOMAXPROCS is set to 1, we get the desired behaviour (i = 0) because
	   one thread finishes completely before the nest one can start.
	   If it's different from 1, we might get 0, positive, or negative numbers.
	*/

	go incrementing()
	go decrementing()

	time.Sleep(100 * time.Millisecond)
	Println("The magic number is:", i)
}
