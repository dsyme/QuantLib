# BernsteinPolynomial Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

This directory contains correspondence tests validating that the Lean model
`FVSquad.BernsteinPolynomial` matches the QuantLib C++ implementation
`BernsteinPolynomial::get(i, n, x)`.

## Route B: Executable Correspondence Tests

Both the C++ and Lean implementations use the same mathematical formula:
`B_{i,n}(x) = C(n,i) * x^i * (1-x)^(n-i)`. The Python test harness computes
the same formula and validates structural properties proved in Lean.

## Running

```bash
python3 formal-verification/tests/bernsteinpolynomial/test_correspondence.py
```

## What's Tested

1. **Reference values** (33 cases): specific numeric evaluations including
   boundaries, linear, and quadratic cases.

2. **Partition of unity** (~126 cases): `sum B_{i,n}(x) = 1` for various n and x.

3. **Symmetry** (~252 cases): `B_{i,n}(x) = B_{n-i,n}(1-x)`.

4. **Non-negativity** (~1155 cases): `B_{i,n}(x) >= 0` for x in [0,1].

5. **de Casteljau recursion** (~140 cases): validates the recursive structure.

## Coverage

- Degrees n = 0..10 (extended to 25 for partition of unity)
- x values spanning [0, 1] at fine granularity
- All key theorems from the Lean file are validated empirically
- Out-of-range indices (i > n) confirmed to return 0

## Limitations

- Tests use Python floating-point (IEEE 754 double), matching C++ semantics
- Very high degrees (n > 50) may show numerical instability not present in exact Lean reals
