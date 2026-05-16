# PrimeNumbers Correspondence Test

🔬 *Lean Squad — automated formal verification.*

## Overview

This test validates behavioural correspondence between the C++ `PrimeNumbers::get(n)` 
implementation (`ql/math/primenumbers.cpp`) and the Lean model `nthPrime(n) = Nat.nth Nat.Prime n`
(`formal-verification/lean/FVSquad/PrimeNumbers.lean`).

## Method

The test reimplements the exact trial-division algorithm from the C++ source (seed table 
of 15 primes, step-by-2 trial division) and compares its output against mathematically 
known prime values.

## Test Cases (1102 total)

- **First 100 primes** (indices 0–99): compared against ground-truth table
- **Spot checks** (3 cases): indices 167, 999, 1228 against known primes
- **Monotonicity** (999 cases): verifies strict increase for indices 0–999

## Running

```bash
g++ -std=c++17 -O2 test_primenumbers.cpp -lm -o test_primes
./test_primes
```

## Results

All 1102 cases pass. The C++ trial-division algorithm produces the mathematically 
correct nth prime for all tested indices, confirming correspondence with the Lean 
model's `Nat.nth Nat.Prime n`.
