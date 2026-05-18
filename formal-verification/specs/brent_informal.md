# Informal Specification: Brent's Root-Finding Method

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Source

- **File**: `ql/math/solvers1d/brent.hpp`
- **Base class**: `ql/math/solver1d.hpp` (provides bracketing, `solve()` entry point)
- **Reference**: Brent, R.P. (1973). *Algorithms for Minimization without Derivatives*. Chapter 4. Also: Press et al., *Numerical Recipes in C*, 2nd edition, §9.3.

## Purpose

Finds a root `x*` of a continuous function `f` such that `f(x*) ≈ 0`, combining the reliability of bisection with the speed of inverse quadratic interpolation and the secant method. Brent's method is guaranteed to converge (like bisection) but converges superlinearly when the function is smooth near the root.

## Preconditions

The base class `Solver1D<Brent>::solve()` establishes the following before calling `solveImpl`:

1. **Valid bracket**: `xMin_` and `xMax_` satisfy `f(xMin_) * f(xMax_) < 0` (sign change guarantees a root exists by IVT)
2. **Initial guess**: `root_` is set to a valid starting point within or near the bracket
3. **Function values cached**: `fxMin_ = f(xMin_)` and `fxMax_ = f(xMax_)` are precomputed
4. **Accuracy**: `xAccuracy > 0` specifies the convergence tolerance
5. **Max evaluations**: `maxEvaluations_ > 0` bounds computational cost

## Postconditions

1. **Root found**: Returns `x*` such that either:
   - `|f(x*)| ≈ 0` (function value close to zero, checked via `close(froot, 0.0)`), or
   - `|xMax_ - root_| / 2 ≤ tolerance` where `tolerance = 2 * ε_mach * |root_| + xAccuracy/2`
2. **Bracket maintained**: Throughout execution, the interval `[root_, xMax_]` (or `[xMax_, root_]`) always contains a sign change
3. **Evaluation count**: If convergence is not achieved within `maxEvaluations_` evaluations, throws `QL_FAIL`

## Algorithm Structure

Brent's method maintains:
- `root_`: current best estimate of the root
- `xMax_`: the other bracket endpoint (opposite sign from `froot`)
- `xMin_`: previous value of `root_` (for interpolation)
- `d`, `e`: step sizes (current and previous) used to control interpolation vs bisection

Each iteration:
1. **Ensure bracket**: if `froot` and `fxMax_` have the same sign, reset `xMax_` to `xMin_` (the previous iterate with opposite sign)
2. **Swap if needed**: ensure `|froot| ≤ |fxMax_|` (best approximation is in `root_`)
3. **Check convergence**: if `|xMid| ≤ tolerance` or `f(root_) ≈ 0`, return
4. **Choose step**:
   - If the previous step was large enough and `|fxMin_| > |froot|` (function is decreasing toward root):
     - If `xMin_ ≈ xMax_`: use **secant method** (linear interpolation)
     - Otherwise: use **inverse quadratic interpolation** (fit parabola through 3 points)
     - Accept the interpolation step only if it stays within bounds and is smaller than half the previous step
   - Otherwise: use **bisection** (`d = xMid`)
5. **Update**: move `xMin_ ← root_`, `root_ += d` (or `± tolerance` if `d` is too small), evaluate `f(root_)`

## Invariants

1. **Bracket invariant**: `f(root_) * f(xMax_) ≤ 0` at the start of each iteration (sign change between `root_` and `xMax_`)
2. **Convergence guarantee**: the bracket width `|xMax_ - root_|` is non-increasing over any two consecutive iterations (bisection fallback ensures this)
3. **Step bound**: the accepted interpolation step is always less than `min(3*xMid*q - |xAcc1*q|, |e*q|) / (2*q)`, ensuring we don't overshoot
4. **Best approximation**: after the swap step, `|f(root_)| ≤ |f(xMax_)|`

## Key Properties for Formal Verification

### P1: Bracket Preservation
If `f(a) * f(b) < 0` initially, then at every iteration the algorithm maintains a pair of points with opposite signs.

### P2: Convergence (Termination)
The algorithm terminates in at most `maxEvaluations` iterations. If it converges, the returned value satisfies the tolerance condition.

### P3: Bisection Fallback Correctness
When interpolation is rejected (step too large or conditions not met), bisection halves the bracket, guaranteeing `O(log(1/ε))` worst-case convergence.

### P4: Inverse Quadratic Interpolation Bounds
The IQI step `p/q` is accepted only when `2*p < min(min1, min2)`, ensuring the step stays within the bracket and is a genuine improvement over bisection.

### P5: Secant Step (Degenerate IQI)
When `xMin_ ≈ xMax_`, the method reduces to the secant method: `p = 2*xMid*s`, `q = 1-s` where `s = froot/fxMin_`.

### P6: Sign Helper Correctness
`sign(a, b)` returns `|a|` if `b ≥ 0` else `-|a|`. This ensures the minimum step `xAcc1` is taken in the correct direction toward `xMax_`.

### P7: Superlinear Convergence (Under Smoothness)
For sufficiently smooth functions near a simple root, Brent's method achieves convergence order approximately 1.618 (golden ratio), faster than bisection's linear convergence.

## Edge Cases

- **Root at bracket endpoint**: if `f(root_) = 0` initially (checked via `close(froot, 0.0)`), returns immediately
- **Flat function near root**: when `|fxMin_|` is not larger than `|froot|`, interpolation is skipped (bisection is safer)
- **Very tight initial bracket**: if `|xMax_ - root_| < 2*ε_mach*|root_| + xAccuracy`, converges immediately
- **Maximum evaluations exceeded**: throws exception (does not return an incorrect answer)
- **Near-identical function values at interpolation points**: the secant/IQI formula may produce very large steps, caught by the acceptance test

## Examples

| f(x) | Bracket | Root | Evals (typical) |
|------|---------|------|-----------------|
| x² - 2 | [1, 2] | √2 ≈ 1.41421 | 5–8 |
| sin(x) | [3, 4] | π ≈ 3.14159 | 4–6 |
| x³ - x - 2 | [1, 2] | ≈ 1.52138 | 5–7 |
| e^x - 3x | [0, 1] | ≈ 0.61906 | 4–6 |

## Inferred Intent

The implementation is adapted from Numerical Recipes. Key design choices:
- The `sign(a, b)` helper replaces `copysign` for portability
- The convergence test uses both absolute tolerance (`xAccuracy`) and a machine-epsilon-relative term (`2*QL_EPSILON*|root_|`)
- The `close(froot, 0.0)` check allows early termination when the function value is essentially zero (uses QuantLib's floating-point comparison utility)
- An extra `f(root_)` evaluation is performed after convergence — this appears to be for the evaluation counter but may be unnecessary

## Open Questions

1. **Final evaluation**: After convergence (`close(froot, 0.0)` or midpoint test), the code does `f(root_); ++evaluationNumber_;` — is this intentional (perhaps for side effects) or a minor inefficiency?
2. **Initial bracket setup**: The initial reorientation (`if froot * fxMin_ < 0 then swap`) assumes a specific relationship between `root_`, `xMin_`, `xMax_` — does the base class guarantee this is always correct?
3. **Tolerance definition**: The tolerance `2*ε*|root_| + 0.5*xAccuracy` mixes absolute and relative — should formal properties use this exact definition or simplify?

## Comparison with Bisection (Already Verified)

The existing `FVSquad.Bisection` module proves similar properties for pure bisection. Brent's method extends this with:
- Superlinear convergence when interpolation succeeds
- The same worst-case guarantee (falls back to bisection)
- More complex loop invariants (tracking `d`, `e`, and the interpolation acceptance)

A Lean formalisation would likely:
- Reuse the bracket-preservation structure from Bisection
- Add a measure showing the bracket width decreases by at least half every two iterations
- Model the interpolation step as a function and prove the acceptance test implies the step is safe
