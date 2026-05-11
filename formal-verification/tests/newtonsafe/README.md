# NewtonSafe Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Overview

This harness validates that the C++ NewtonSafe bracketed Newton-Raphson solver
(`ql/math/solvers1d/newtonsafe.hpp`) behaves consistently with the Lean 4
formal model (`FVSquad.NewtonSafe`).

## What is tested

- **P1**: Bisection midpoint lies within bracket (12 cases)
- **P2**: Bisection halves bracket width
- **P5**: Newton step used when iterate is in-bracket and converging fast
- **P6**: Bisection used when convergence is too slow
- **P8**: Zero derivative triggers bisection (and f=0 edge case)
- **P9**: Orient produces correct bracket ordering (6 cases)
- **P11**: Convergence on 5 test functions (x²-2, x³-x-1, sin(x), eˣ-3, x)
- **Step-by-step**: Individual step results match expected Newton computations
- **Worst case**: Convergence with degenerate derivative (bisection-only path)
- **Edge cases**: Root at endpoint, very tight bracket

## Build and run

```bash
g++ -std=c++17 -O2 -o test_newtonsafe test_newtonsafe.cpp -lm
./test_newtonsafe
```

## Results

49/49 tests passing (run 61, 2026-05-11).

## What is NOT tested

- The `Solver1D` base class template machinery
- `evaluationNumber_` tracking and `maxEvaluations_` enforcement
- The redundant `f(root_)` call before return in the C++ code
- `QL_FAIL` exception path (modelled as `Option.none` in Lean)
- `Null<Real>()` derivative check
