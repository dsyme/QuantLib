# RichardsonExtrapolation Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

This directory contains correspondence tests validating that the Lean model
`FVSquad.RichardsonExtrapolation` matches the QuantLib C++ implementation
`RichardsonExtrapolation::operator()(t)`.

## Route B: Executable Correspondence Tests

The C++ implementation computes:
  result = (t^n * f(Δh/t) - f(Δh)) / (t^n - 1)

The Lean model uses the same formula over exact reals. The Python harness
validates structural properties proved in Lean using floating-point arithmetic.

## Running

```bash
python3 formal-verification/tests/richardsonextrapolation/test_correspondence.py
```

## What's Tested

1. **Exactness** (8 cases): if f(h) = f₀ + α·h^n, extrapolation recovers f₀.
2. **Constant preservation** (60 cases): constant functions are preserved.
3. **Linearity** (36 cases): extrapolation is a linear operator.
4. **Order improvement** (9 cases): leading error term is cancelled.
5. **Numerical examples** (2 cases): practical usage (trapezoidal rule acceleration).

## Coverage

- Multiple convergence orders n = 1, 2, 3, 4
- Multiple subdivision ratios t = 2, 3, 4, 5, 10
- Step sizes from 0.01 to 2.0
- All key theorems from the Lean file validated empirically

## Limitations

- Only models the known-order extrapolation formula
- Unknown-order mode (Brent solver) not tested here (see Bisection tests)
- Floating-point tolerance used (1e-12); Lean proofs use exact reals
