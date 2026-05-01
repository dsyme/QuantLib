# Bisection Solver Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

These tests validate that the Lean 4 bisection model (`FVSquad/Bisection.lean`) corresponds
to the C++ QuantLib implementation (`ql/math/solvers1d/bisection.hpp`).

**Route**: B (executable correspondence tests — C++ codebase, Aeneas not applicable).

## How to Run

```bash
cd formal-verification/tests/bisection
python3 test_bisection.py
```

## What is Tested

- **Rational solver** (Python `Fraction`): exact match to the Lean model's `ℚ` semantics
- **Float solver** (Python `float`): mirrors C++ `double` bisection behaviour
- **Cross-check**: both solvers agree on all 22 test cases

### Test Case Categories (22 total)

| Category | Cases | Description |
|----------|-------|-------------|
| Linear functions | 6 | `f(x) = ax + b` with known rational roots |
| Quadratic functions | 4 | `f(x) = x² - c` including irrational roots |
| Cubic functions | 3 | `f(x) = x³ - x` with three roots |
| Exact zero at midpoint | 1 | Tests early termination on exact zero |
| Tight bracket | 1 | Very small accuracy requirement |
| Convergence rate | 5 | Accuracies from 1e-1 to 1e-12 |
| Large bracket | 1 | Wide interval [-1000, 1000] |
| Reversed orientation | 1 | `f(xMin) > 0` (opposite sign ordering) |

## Results

All 22 cases pass. Rational and float solvers agree exactly on all cases, confirming
that the Lean model's algorithm produces identical results to the C++ implementation
(within the rational/float correspondence boundary).

## Limitations

- Tests use Python, not C++ — the float comparison simulates C++ `double` semantics
  but is not a direct C++ execution.
- The Lean model uses exact rationals; C++ uses IEEE 754 doubles. Agreement is verified
  through the float reference implementation.
- Does not test the `evaluationNumber_` tracking or the `QL_FAIL` path from C++.
