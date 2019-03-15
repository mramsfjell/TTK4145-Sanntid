import math
T = [50,30,20]
C = [15,10,5]
Results = [0,0,0]
for i in range(3):
    prev=0
    curr=1
    while prev != curr:
        prev = curr
        curr = C[i]
        for j in range(i+1,3):
            curr += math.ceil(prev/T[j])*C[j]
    Results[i] = curr
print(Results)
