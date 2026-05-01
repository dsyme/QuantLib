# Informal Specification: Bisection 1-D Solver

🔬 *Lean Squad — automated formal verification.*

**Target**: `ql/math/solvers1d/bisection.hpp`
**Base class**: `ql/math/solver1d.hpp` (provides bracketing and setup)

## Purpose

The Bisection solver finds a root of a continuous real-valued function `f` on an interval
`[xMin, xMax]` where `f` changes sign. It implements the classical bisection method:
repeatedly halving the interval and selecting the sub-interval where the sign change persists.

## Preconditions

The base class `Solver1D<Bisection>::solve(f, accuracy, guess, step)` ensures the following
hold before `solveImpl` is called:

1. **Valid bracket**: `xMin_` and `xMax_` form a bracket — `f(xMin_) * f(xMax_) ≤ 0`
2. **Sign information**: `fxMin_ = f(xMin_)` and `fxMax_ = f(xMax_)` are stored
3. **Positive accuracy**: `accuracy > 0` (enforced: at least `QL_EPSILON`)
4. **Evaluation budget**: `maxEvaluations_` bounds the number of `f` evaluations

## Postconditions

When `solveImpl` returns a value `r`:

1. **Approximate root (x-accuracy)**: `|r - ξ| < xAccuracy` where `ξ` is a true root in
   the bracket, OR `f(r) ≈ 0` (within machine epsilon via `close(fMid, 0.0)`)
2. **Within bracket**: `xMin_ ≤ r ≤ xMax_` (the returned value lies in the original bracket)
3. **Evaluation count**: at most `maxEvaluations_` function evaluations were performed
4. **Failure mode**: if no root is found within the budget, an exception is thrown (never
   returns a spurious value)

## Invariants

At each iteration of the bisection loop:

1. **Bracket maintenance**: the interval `[root_, root_ + dx]` (or equivalently the tracked
   sub-interval) always contains a root — i.e., `f` has opposite signs at the endpoints
2. **Interval halving**: `|dx|` is halved each iteration, so after `k` iterations,
   `|dx| = |xMax_ - xMin_| / 2^k`
3. **Convergence guarantee**: since `|dx| → 0` geometrically, the method converges in at
   most `⌈log₂((xMax_ - xMin_) / xAccuracy)⌉` iterations

## Algorithm Description

1. **Orient**: arrange so that `f > 0` lies at `root_ + dx`:
   - If `fxMin_ < 0`: set `root_ = xMin_`, `dx = xMax_ - xMin_`
   - Else: set `root_ = xMax_`, `dx = xMin_ - xMax_`
2. **Iterate**: repeat until convergence or budget exhaustion:
   - Halve: `dx = dx / 2`
   - Midpoint: `xMid = root_ + dx`
   - Evaluate: `fMid = f(xMid)`
   - Update: if `fMid ≤ 0`, set `root_ = xMid` (maintains the invariant that
     `f(root_) ≤ 0` and `f(root_ + dx) > 0`)
   - Check: if `|dx| < xAccuracy` or `close(fMid, 0)`, return `root_`
3. **Fail**: throw if `maxEvaluations_` exceeded

## Properties to Verify (FV Candidates)

### P1: Convergence Rate (High value)
After `k` iterations, the bracket width is exactly `(xMax_ - xMin_) / 2^k`.
- **Spec complexity**: one line (geometric sequence)
- **Impl complexity**: loop with orientation logic
- **Ratio**: High

### P2: Bracket Invariant Maintenance (High value)
At every iteration, the interval `[root_, root_ + dx]` contains a root (sign change).
- **Spec**: `f(root_) ≤ 0 ∧ f(root_ + dx) ≥ 0` (after orientation)
- **Ratio**: High — simple invariant, non-trivial to maintain across the sign-oriented update

### P3: Termination Bound (Medium value)
The algorithm terminates in at most `⌈log₂(width / accuracy)⌉` iterations.
- **Spec**: `iterations ≤ Nat.log2 (width / accuracy) + 1`
- **Ratio**: Medium

### P4: Accuracy Guarantee (High value)
The returned value `r` satisfies `|r - ξ| < xAccuracy` for some root `ξ` in the bracket.
- This follows from P1 + P2: if the bracket always contains a root and the bracket shrinks
  below `xAccuracy`, then `r` is within `xAccuracy` of that root.
- **Ratio**: High — the conclusion is one inequality; the proof chains two invariants

### P5: Idempotence of Root Update (Low value)
If `fMid = 0` exactly, updating `root_ = xMid` and returning is correct.
- **Ratio**: Low (trivial)

## Edge Cases

- **Root at endpoint**: if `f(xMin_) = 0` or `f(xMax_) = 0`, the base class catches this
  before calling `solveImpl`. The `close(fMid, 0.0)` check in the loop handles exact zeros.
- **Very tight bracket**: if `xMax_ - xMin_ < xAccuracy` initially, the first iteration
  returns immediately (since `|dx/2| < xAccuracy`).
- **Maximum evaluations**: with default `MAX_FUNCTION_EVALUATIONS = 100` and accuracy ε,
  the method can resolve brackets up to width `2^100 * ε ≈ 10^30 * ε`.
- **Flat function**: if `f` is constant zero in the bracket, every midpoint satisfies
  `fMid ≤ 0`, so `root_` drifts leftward; the `close(fMid, 0)` check triggers immediately.

## Inferred Intent

- The orientation step ensures a consistent invariant (`f(root_) ≤ 0`) regardless of which
  endpoint is negative. This simplifies the update rule to a single comparison.
- The final `f(root_)` call before return appears to be for side-effect purposes (evaluation
  counting consistency) — it does not affect the returned value.
- The `close(fMid, 0.0)` check provides an early exit for exact or near-exact roots,
  avoiding unnecessary further halving.

## Open Questions

1. **The final `f(root_)` call**: after the convergence check passes, the code calls
   `f(root_)` and increments `evaluationNumber_` before returning. This seems redundant
   for correctness — is it for compatibility with the base class's evaluation tracking?
2. **`fMid ≤ 0` vs `fMid < 0`**: the update uses `≤ 0`, meaning exact zeros cause
   `root_ = xMid`. This is correct but means the invariant is `f(root_) ≤ 0` (not strict).
   Does this matter for any caller?
3. **Accuracy semantics**: the base class documentation notes ambiguity about whether
   accuracy is for `x` or `f(x)`. The bisection implementation uses x-accuracy (`|dx|`)
   as the primary criterion, with `close(fMid, 0)` as a secondary f-accuracy check.

## Approximations for Lean Model

- Model `f` as a pure function `ℚ → ℚ` (or `ℝ → ℝ`) rather than a C++ callable
- Ignore floating-point rounding — use exact arithmetic
- Ignore the `close()` early-exit (or model it as exact zero check)
- Ignore `evaluationNumber_` tracking — focus on the mathematical convergence
- Model as a recursive function with fuel (iteration count) rather than a mutable loop
- The `QL_FAIL` path maps to `Option.none` in Lean (partial function)
