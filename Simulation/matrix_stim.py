import numpy as np
import random

N = 2
M = 2
OP = 2
CYCLES = 3
W_CYCLES = M #cycles required for weight loading

# activations and expected partial sums require a temporal dimension (CYCLES) due to the skew
activ   = np.zeros((CYCLES, M, N, OP), dtype=int)
weights = np.zeros((W_CYCLES, M, N, N, OP), dtype=int)
init_parsum = np.zeros((M, N), dtype=int) 
expected_parsum = np.zeros((CYCLES, M, N), dtype=int) 


# loading phase
for t in range(W_CYCLES):
    for x in range(M):
        for y in range(N):
            for z in range(N):
                for w in range(OP):
                    weights[t][x][y][z][w] = random.randrange(1, 20)
        
for x in range(M):
    for y in range(N):
        init_parsum[x][y] = random.randrange(1, 20)

for t in range(CYCLES):
    for x in range(M):
        for y in range(N):
            for z in range(OP):
                activ[t][x][y][z] = random.randrange(1, 20)


for t in range(CYCLES):
    expected_parsum[t] = np.copy(init_parsum)

for t in range(CYCLES):
    expected_parsum[t] = np.copy(init_parsum)

# calculate the final answer dropping out of the bottom for each batch 't'
for t in range(CYCLES):
    for c in range(M):       
        for r in range(M):   
            w_t = M - 1 - r
            for y in range(N):
                for z in range(N):
                    for w in range(OP):                        
                        expected_parsum[t][c][y] = expected_parsum[t][c][y] + activ[t][r][y][w] * weights[w_t][c][y][z][w]

        
# creating output files for SystemVerilog
with open("activations.txt", "w") as f:
    for t in range(CYCLES):
        for x in range(M):
            for y in range(N):
                for z in range(OP):
                    f.write(str(activ[t][x][y][z]) + "\n")
            
with open("weights.txt", "w") as f:
    for t in range(W_CYCLES):
        for x in range(M):
            for y in range(N):
                for z in range(N):
                    for w in range(OP):
                        f.write(str(weights[t][x][y][z][w]) + "\n")

with open("init_parsum.txt", "w") as f:
    for x in range(M):
        for y in range(N): 
            f.write(str(init_parsum[x][y]) + "\n")

with open("expected_parsum.txt", "w") as f:
    for t in range(CYCLES):
        for x in range(M):
            for y in range(N): 
                f.write(str(expected_parsum[t][x][y]) + "\n")\
                
print("Generation of stimuli finished successfully!")