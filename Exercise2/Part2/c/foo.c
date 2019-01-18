#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>

int i = 0;
sem_t semaphore;

// Note the return type: void*
void* incrementingThreadFunction(){
    for (int j = 0; j < 1000000; j++) {
	    // TODO: sync access to i
        sem_wait(&semaphore);
        i++;
        sem_post(&semaphore);
    }
    return NULL;
}

void* decrementingThreadFunction(){
    for (int j = 0; j < 1000001; j++) {
	    // TODO: sync access to i
	    sem_wait(&semaphore);
        i--;
        sem_post(&semaphore);
    }
    return NULL;
}


int main(){
    pthread_t incrementingThread, decrementingThread;

    sem_init(&semaphore, 0, 1);
    
    pthread_create(&incrementingThread, NULL, incrementingThreadFunction, NULL);
    pthread_create(&decrementingThread, NULL, decrementingThreadFunction, NULL);
    
    pthread_join(incrementingThread, NULL);
    pthread_join(decrementingThread, NULL);
    
    printf("The magic number is: %d\n", i);
    return 0;
}
