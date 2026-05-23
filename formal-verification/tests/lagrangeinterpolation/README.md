# Lagrange Interpolation — Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

These tests validate that the Lean model in `FVSquad/LagrangeInterpolation.lean`
correctly captures the semantics of the C++ barycentric Lagrange interpolation
in `ql/math/interpolations/lagrangeinterpolation.hpp`.

## Route

**Route B**: Executable correspondence tests (C++ codebase, Aeneas not applicable).

## What is tested

| Test | Cases | Property |
|------|-------|----------|
| Node interpolation | 4 | Evaluating at a node returns that node's y-value |
| Constant exactness | 4 | Constant function is reproduced exactly |
| Linear exactness | 4 | Linear function is reproduced exactly |
| Quadratic exactness | 3 | Degree-2 polynomial through 3 nodes is exact |
| Scaling invariance | 9 | Different scaling constants c give same result |
| Classical equivalence | 4 | Barycentric form = classical Lagrange form |
| C++ correspondence | 4 | Float implementation matches rational model (tol 1e-12) |
| Weight denom nonzero | 5 | Distinct nodes yield non-zero weight denominators |

**Total: 37 test assertions across 8 test functions.**

## How to run

```bash
python3 formal-verification/tests/lagrangeinterpolation/test_lagrange.py
```

## Limitations

- The C++ correspondence test uses a Python float reimplementation of the C++
  algorithm, not the actual C++ binary. The logic is identical but compiled
  differently.
- The epsilon-based node proximity check is tested implicitly (exact node match).
