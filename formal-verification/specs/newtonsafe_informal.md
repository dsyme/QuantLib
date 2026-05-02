# Informal Specification: NewtonSafe (Bracketed Newton-Raphson Solver)

🔬 *Lean Squad — automated formal verification.*

**Target**: `ql/math/solvers1d/newtonsafe.hpp` — `NewtonSafe::solveImpl`

**Source**: Numerical Recipes in C, 2nd ed. (Press, Teukolsky, Vetterling, Flannery), §9.4 "Newton-Raphson Method Using Derivative Information" combined with bisection safeguard.

---

## Purpose

`NewtonSafe` finds a root of a function `f(x) = 0` within a bracket `[xMin, xMax]` where `f` changes sign. It combines Newton-Raphson steps (using the derivative `f'(x)`) with bisection fallback to guarantee convergence. When Newton's method would step outside the bracket or converge too slowly, the algorithm falls back to a bisection step, ensuring the bracket always shrinks.

This is a critical numerical component used throughout QuantLib for implied volatility calculations, yield solving, and calibration.

---

## Preconditions

1. **Valid bracket**: `f(xMin) * f(xMax) < 0` — the function changes sign across the interval. (Established by the base class `Solver1D::solve` before calling `solveImpl`.)
2. **Positive accuracy**: `xAccuracy > 0`.
3. **Derivative available**: `f.derivative(x)` is defined and returns a finite value for all `x` in `[xMin, xMax]`. The algorithm explicitly requires `dfroot != Null<Real>()`.
4. **Valid initial guess**: `root_` lies within `[xMin, xMax]`. (Set by base class.)
5. **Max evaluations**: `maxEvaluations_ ≥ 1`.
6. **Continuity**: `f` is continuous on `[xMin, xMax]` (implied by the intermediate value theorem requirement for bracketing).

---

## Postconditions

1. **Root approximation**: On success, returns a value `x*` such that `|dx| < xAccuracy`, where `dx` is the last step size. This means the returned root is within `xAccuracy` of the previous iterate.
2. **Bracket preserved**: Throughout execution, `xl ≤ root_ ≤ xh` and `f(xl) ≤ 0 ≤ f(xh)` (bracket invariant). The root lies within the maintained bracket.
3. **Termination**: Either converges within `maxEvaluations_` function evaluations, or raises `QL_FAIL`.
4. **Final evaluation**: Before returning, `f(root_)` is evaluated one final time (for consistency with the evaluation counter).

---

## Invariants

### Bracket Invariant
At all times during the loop:
- `f(xl) < 0` and `f(xh) > 0` (or `f(xl) ≤ 0`, `f(xh) ≥ 0` if exact zero is hit)
- `xl ≤ xh`
- `root_` ∈ `[xl, xh]`

### Monotone Bracket Shrinkage
The bracket `[xl, xh]` never grows: after each iteration, either `xl` increases or `xh` decreases (or neither, if `froot = 0`).

### Step Size
- `dxold` records the step before last
- `dx` records the last step
- The Newton step is `dx = froot / dfroot`
- The bisection step is `dx = (xh - xl) / 2`

---

## Algorithm Description

1. **Orient**: Arrange `xl`, `xh` so that `f(xl) < 0` and `f(xh) > 0`.
2. **Initialize**: Set `dxold = xMax - xMin`, `dx = dxold`. Evaluate `froot = f(root_)` and `dfroot = f'(root_)`.
3. **Loop** (up to `maxEvaluations_`):
   a. **Decide Newton vs Bisection**: Use bisection if either:
      - The Newton step would land outside `[xl, xh]`:
        `((root_ - xh) * dfroot - froot) * ((root_ - xl) * dfroot - froot) > 0`
      - The function is not decreasing fast enough:
        `|2 * froot| > |dxold * dfroot|`
   b. **Bisection step**: `dxold = dx`, `dx = (xh - xl) / 2`, `root_ = xl + dx`.
   c. **Newton step**: `dxold = dx`, `dx = froot / dfroot`, `root_ -= dx`.
   d. **Convergence check**: If `|dx| < xAccuracy`, evaluate `f(root_)` once more and return `root_`.
   e. **Update bracket**: Evaluate `froot = f(root_)`, `dfroot = f'(root_)`. If `froot < 0`, set `xl = root_`; else set `xh = root_`.
4. **Fail** if loop exhausts evaluations.

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| `f(root_) = 0` at initial guess | Not checked — the loop proceeds. Convergence depends on `dx` becoming small. |
| `f'(root_) = 0` | The Newton step `froot/dfroot` would be infinite. The bisection guard catches this because `|2·froot| > |0·dxold|` when `froot ≠ 0`. |
| Very flat function near root | Falls back to bisection, which always makes progress by halving the bracket. |
| Root at bracket endpoint | `dx = (xh - xl)/2` converges to the endpoint. |
| `xAccuracy` extremely small | May exhaust `maxEvaluations_` due to floating-point precision limits. |
| `dfroot` is `Null<Real>()` | Throws `QL_REQUIRE` immediately (precondition violation). |
| Single evaluation allowed | One iteration: either converges or fails. |

---

## Examples

From the test suite (`test-suite/solvers.cpp`):

| Function | Root | Bracket | Expected |
|----------|------|---------|----------|
| `f(x) = x² - 1` | 1.0 | guess=0.5, step=0.1 | 1.0 ± ε |
| `f(x) = 1 - x²` | 1.0 | guess=0.5, step=0.1 | 1.0 ± ε |
| `f(x) = atan(x-1)` | 1.0 | guess=0.5, step=0.1 | 1.0 ± ε |
| All above | 1.0 | bracketed [0.5, 1.5] | 1.0 ± ε |

Tested at accuracies: 1e-4, 1e-6, 1e-8.

---

## Inferred Intent

1. **Safety over speed**: The algorithm sacrifices potential Newton-Raphson quadratic convergence for guaranteed convergence by always maintaining a valid bracket. This is essential for financial applications where solver failure is unacceptable.
2. **The "fast enough" heuristic**: The condition `|2·froot| > |dxold·dfroot|` tests whether Newton's method is reducing the step size fast enough. If not, bisection is more reliable.
3. **The out-of-bracket test**: The product test `((root_ - xh)·f' - f)·((root_ - xl)·f' - f) > 0` checks whether the Newton iterate `root_ - f/f'` lies outside `[xl, xh]`. This is equivalent to checking the signs at the bracket boundaries.

---

## Key Properties for Formal Verification

1. **Bracket preservation**: After each iteration, `f(xl) < 0` and `f(xh) ≥ 0` (or vice versa).
2. **Bracket monotone shrinkage**: `xh - xl` is non-increasing across iterations.
3. **Newton-bisection switching correctness**: When the Newton step is rejected, the bisection step always lies within `[xl, xh]`.
4. **Bisection step halves the interval**: After a bisection step, `xh - xl` is halved.
5. **Convergence**: Under continuity + bracketing, the algorithm terminates within O(log((xMax-xMin)/accuracy)) bisection steps in the worst case.
6. **Derivative zero handling**: When `f'(root_) = 0` and `f(root_) ≠ 0`, the bisection guard is triggered.

**Spec-to-implementation complexity ratio**: **High**. The key safety properties (bracket preservation, monotone shrinkage, guaranteed convergence) can be stated concisely as algebraic invariants, while the implementation involves intricate conditional logic mixing Newton and bisection steps with multiple state variables.

---

## Open Questions

1. **Final f(root_) call**: Before returning, the code evaluates `f(root_)` and increments the counter but discards the value. Is this intentional for side-effect tracking, or is it vestigial?
2. **Orientation via dxold**: The comment notes `dxold = xMax_ - xMin_` differs from Numerical Recipes' `dxold = fabs(xMax_ - xMin_)`. Since the base class guarantees `xMax_ > xMin_`, these are equivalent — but the comment suggests awareness of a subtle difference.
3. **Convergence criterion**: The check `|dx| < xAccuracy` tests the step size, not `|f(root_)|`. This is an x-accuracy criterion. Is this always appropriate, or would f-accuracy sometimes be preferred?
