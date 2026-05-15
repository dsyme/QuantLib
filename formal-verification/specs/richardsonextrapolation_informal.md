# Richardson Extrapolation — Informal Specification

🔬 *Lean Squad — automated formal verification.*

**Source**: `ql/math/richardsonextrapolation.hpp`, `ql/math/richardsonextrapolation.cpp`

## Purpose

Richardson Extrapolation accelerates convergence of a numerical approximation sequence.
Given a function `f(Δh)` that approximates some limit `f₀` with an error term
`α·(Δh)^n + O((Δh)^(n+1))`, the technique combines evaluations at different step sizes
to cancel the leading error term, producing a more accurate estimate of `f₀`.

The class provides two modes:
1. **Known order** (`operator()(t)`): when the convergence order `n` is known a priori
2. **Unknown order** (`operator()(t, s)`): estimates `n` from three evaluations, then extrapolates

## Preconditions

### Constructor
- `f`: a function `ℝ → ℝ` representing the numerical approximation at a given step size
- `delta_h > 0`: the initial (coarsest) step size
- `n`: the order of convergence (optional; if `Null<Real>()`, unknown-order mode is used)

### Known-order operator `operator()(t)`
- `t > 1`: the refinement scaling factor
- `n` must have been provided at construction (not null)

### Unknown-order operator `operator()(t, s)`
- `t > 1` and `s > 1`: two distinct refinement scaling factors
- `t > s`: the first factor must be larger than the second

## Postconditions

### Known-order formula
Given evaluations `f(Δh)` and `f(Δh/t)`, the extrapolated value is:

```
result = (t^n · f(Δh/t) - f(Δh)) / (t^n - 1)
```

This cancels the leading `O((Δh)^n)` error term exactly when the error expansion
`f(Δh) = f₀ + α·(Δh)^n + O((Δh)^(n+1))` holds.

### Unknown-order formula
Given three evaluations `f(Δh)`, `f(Δh/t)`, `f(Δh/s)`:
1. Find `k` (estimated order) by solving via Brent's method:
   ```
   [f(Δh/t) + (f(Δh/t) - f(Δh))/(t^k - 1)] = [f(Δh/s) + (f(Δh/s) - f(Δh))/(s^k - 1)]
   ```
2. Then extrapolate using `s` and `k`:
   ```
   result = (s^k · f(Δh/s) - f(Δh)) / (s^k - 1)
   ```

## Invariants

- The class stores `delta_h`, `f(delta_h)`, `n`, and the function `f` immutably after construction.
- The extrapolation formula is algebraically exact for functions of the form `f₀ + α·h^n` (no higher-order terms).

## Key Properties to Verify

1. **Exactness for polynomial error**: If `f(h) = f₀ + α·h^n` exactly (no higher-order terms),
   then `operator()(t)` returns exactly `f₀` for any `t > 1`.

2. **Consistency with known order**: When the true order `n` is known, the known-order and
   unknown-order formulas produce the same result (the unknown-order mode should recover `n`).

3. **Symmetry in the limit**: As the error expansion is purely `α·h^n`, the result is
   independent of the choice of `t` (it always recovers `f₀`).

4. **Identity when f is constant**: If `f(h) = c` for all `h`, then `operator()(t) = c`.

5. **Linearity**: Richardson extrapolation is linear in `f`: if `g = a·f + b·h`, then
   `Richardson(g)(t) = a·Richardson(f)(t) + b·Richardson(h)(t)`.

6. **Order improvement**: For a function with error `α·h^n + β·h^(n+1) + ...`, the
   extrapolated result has error `O(h^(n+1))` — the order of accuracy is improved by 1.

## Edge Cases

- `t = 1`: rejected by precondition (`t > 1` required)
- `n` unknown and no root found in `[0.05, 15.1]`: throws QL_REQUIRE failure
- `f` constant: should return the constant value regardless of `t`, `n`
- `n = 0`: degenerate case — `t^0 = 1`, division by zero; not guarded in code
- `delta_h` very small: may cause floating-point issues in `f(delta_h/t)`

## Examples

### Example 1: Exact polynomial error
```
f(h) = 1.0 + 3.0·h^2  (f₀ = 1.0, α = 3.0, n = 2)
delta_h = 1.0, t = 2.0

f(1.0) = 4.0
f(0.5) = 1.75
t^n = 4.0

result = (4.0 · 1.75 - 4.0) / (4.0 - 1.0) = (7.0 - 4.0) / 3.0 = 1.0 ✓
```

### Example 2: Constant function
```
f(h) = 5.0 for all h
delta_h = 1.0, t = 2.0, n = 2

f(1.0) = 5.0, f(0.5) = 5.0, t^n = 4.0
result = (4.0 · 5.0 - 5.0) / 3.0 = 15.0/3.0 = 5.0 ✓
```

## Open Questions

1. **Division by zero when n = 0**: `t^n - 1 = 0` causes undefined behaviour. Should this
   be guarded? The C++ code does not check for this.
2. **Brent solver convergence**: The search for `k` uses a fixed bracket `[0.05, 15.1]`.
   Are there legitimate cases where `k` lies outside this range?
3. **Numerical stability**: When `t^n` is very close to 1 (small `n`), the formula suffers
   from catastrophic cancellation. Is this a practical concern?

## Inferred Intent

The class is designed for use in numerical integration and PDE solvers where the convergence
order is known from theory (e.g., trapezoidal rule has `n=2`, Simpson's has `n=4`). The
unknown-order mode is a fallback for empirical convergence acceleration. The implementation
prioritises algebraic correctness of the extrapolation formula over numerical robustness.
