# Brent Solver Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

These tests validate that the Lean 4 Brent model (`FVSquad/Brent.lean`) corresponds
to the C++ QuantLib implementation (`ql/math/solvers1d/brent.hpp`).

**Route**: B (executable correspondence tests — C++ codebase, Aeneas not applicable).

## How to Run

```bash
cd formal-verification/tests/brent
python3 test_brent.py
```

## What is Tested

The Lean model simplifies Brent's method to always-bisection (the fallback guarantee),
operating on exact rationals (ℚ). The tests validate:

1. **Lean model correctness**: The rational bisection-only model converges for all test
   cases and finds roots within the specified accuracy.
2. **Full Brent correspondence**: A full Python Brent implementation (with inverse
   quadratic interpolation and secant steps, matching C++ logic) also converges.
3. **Conservative guarantee**: The bisection-only model is a sound conservative
   abstraction — the full algorithm converges at least as fast.

### Test Case Categories (14 total)

| Category | Cases | Description |
|----------|-------|-------------|
| Linear functions | 4 | `f(x) = ax + b` with known rational roots |
| Quadratic functions | 3 | `f(x) = x² - c` including irrational roots |
| Cubic functions | 2 | Higher-degree polynomials |
| Transcendental approx | 2 | sin(x) and exp(x) via Taylor (rational model) |
| Wide/tight brackets | 2 | Stress tests for convergence |
| Exact zero | 1 | Tests early termination |

## Correspondence Claim

The Lean model is a **conservative abstraction** of the C++ Brent implementation:
- It always uses bisection (guaranteed halving) whereas C++ also uses interpolation
- It uses exact ℚ arithmetic whereas C++ uses IEEE 754 `double`
- Any root found by the Lean model within accuracy ε is guaranteed to be within
  ε of a true root (by the bisection convergence theorems proved in the Lean file)
- The full implementation converges at least as fast as the model

## Known Divergences

| Aspect | Lean Model | C++ Implementation |
|--------|-----------|-------------------|
| Arithmetic | Exact ℚ | IEEE 754 double |
| Step choice | Always bisection | IQI / secant / bisection |
| Tolerance | Pure `accuracy` | `accuracy + 2ε|root|` |
| Zero check | Exact `froot = 0` | `close(froot, 0.0)` |

These divergences are documented in `CORRESPONDENCE.md` and do not invalidate the
proved properties (which concern convergence rate of the bisection component).
