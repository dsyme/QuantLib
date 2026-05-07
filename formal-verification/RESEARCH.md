# Formal Verification Research — QuantLib

🔬 *Lean Squad — automated formal verification.*

## Overview

**Repository**: dsyme/QuantLib — a comprehensive C++ library for quantitative finance.
**Language**: C++ (header-heavy, template-heavy design)
**FV Tool**: Lean 4 + Mathlib
**Aeneas applicable**: No (C++ codebase, not Rust)

## Approach

QuantLib implements well-known financial mathematics with textbook formulas. This makes it
an excellent FV target: the **specifications are mathematical and well-understood**, while
the implementations involve floating-point arithmetic, edge-case handling, and multiple
convention variants that are error-prone.

Our strategy:
1. Model the pure mathematical core of each target in Lean 4 using rationals or reals
2. State correctness properties as algebraic laws (round-trips, identities, monotonicity)
3. Prove properties using Mathlib's real analysis and algebra libraries
4. Document where the Lean model diverges from the C++ (floating-point, day-counting)

## Candidate Survey

### 1. InterestRate (compoundFactor / impliedRate) — **TOP PRIORITY**

- **Files**: `ql/interestrate.hpp`, `ql/interestrate.cpp` (~360 lines)
- **What it does**: Encapsulates interest rate compounding algebra across 5 modes
  (Simple, Compounded, Continuous, SimpleThenCompounded, CompoundedThenSimple)
- **Key functions**: `compoundFactor(t)`, `impliedRate(compound, ...)`, `equivalentRate(...)`
- **Properties to verify**:
  - Round-trip: `impliedRate(compoundFactor(r, t), t) = r` for each compounding mode
  - Identity at zero: `compoundFactor(0, t) = 1` for all t ≥ 0
  - Positivity: `compoundFactor(r, t) > 0` for valid inputs
  - Monotonicity: `compoundFactor` is increasing in both `r` and `t`
- **Spec-to-impl complexity ratio**: **High** — the spec is a handful of algebraic laws;
  the implementation is a 5-way switch with frequency handling and edge cases
- **Proof tractability**: Good. Algebraic properties over reals; Mathlib has `Real.exp`,
  `Real.rpow`, `mul_comm`, `exp_pos`, etc.
- **Approximations**: Model uses exact reals (not IEEE 754 doubles). Day counting abstracted.

### 2. Actual360 Day Counter — **QUICK WIN**

- **File**: `ql/time/daycounters/actual360.hpp` (~65 lines)
- **What it does**: Computes year fraction as `daysBetween(d1,d2) / 360.0`
- **Properties**:
  - Formula correctness: `yearFraction(d1, d2) = dayCount(d1, d2) / 360`
  - Non-negativity: result ≥ 0 when d2 ≥ d1
  - Additivity: `yearFraction(d1,d2) + yearFraction(d2,d3) = yearFraction(d1,d3)`
- **Spec-to-impl ratio**: **High** — trivial spec, but the includeLastDay variant adds subtlety
- **Proof tractability**: Very easy. Pure arithmetic.

### 3. LinearInterpolation

- **File**: `ql/math/interpolations/linearinterpolation.hpp`
- **Properties**: knot interpolation, affine-between-points, monotonicity preservation
- **Spec-to-impl ratio**: **Medium-High**
- **Proof tractability**: Moderate (requires reasoning about sorted sequences)

### 4. Thirty360 Day Counter

- **Files**: `ql/time/daycounters/thirty360.hpp`, `thirty360.cpp`
- **Properties**: ISDA/BMA/ISMA formula correctness, consistency across variants
- **Spec-to-impl ratio**: **Medium** — complex date adjustment rules
- **Proof tractability**: Moderate (many case splits for date adjustments)

### 5. NormalDistribution

- **Files**: `ql/math/distributions/normaldistribution.hpp`, `.cpp`
- **Properties**: range [0,1], monotonicity, symmetry about 0, CDF/InvCDF round-trip
- **Spec-to-impl ratio**: **Medium** — abstract properties are simple but implementation
  uses polynomial approximations
- **Proof tractability**: Hard for full correctness; feasible for abstract properties

### 8. Actual365Fixed (Standard) — **QUICK WIN**

- **File**: `ql/time/daycounters/actual365fixed.hpp` (~84 lines)
- **What it does**: Computes year fraction as `daysBetween(d1,d2) / 365.0` (Standard convention). Also has Canadian Bond and No Leap variants.
- **Properties**:
  - Formula correctness: `yearFraction(d1, d2) = dayCount(d1, d2) / 365`
  - Non-negativity: result ≥ 0 when d2 ≥ d1
  - Additivity: `yearFraction(d1,d2) + yearFraction(d2,d3) = yearFraction(d1,d3)`
  - Scaling relationship to Actual360: `yearFraction_365(d1,d2) = yearFraction_360(d1,d2) * 360/365`
- **Spec-to-impl ratio**: **High** — trivial mathematical spec, similar to Actual360
- **Proof tractability**: Very easy. Reuse Actual360 proof patterns.
- **Approximations**: Same as Actual360 — dates modelled as Int offsets.

### 9. Floating-Point Closeness (`close` / `close_enough`) — **HIGH VALUE**

- **File**: `ql/math/comparison.hpp` (~145 lines)
- **What it does**: Implements Knuth's floating-point comparison: `close(x,y)` checks `|x-y| ≤ ε|x| ∧ |x-y| ≤ ε|y|`; `close_enough(x,y)` uses `∨` instead. Used pervasively throughout QuantLib for numerical equality.
- **Properties to verify**:
  - Reflexivity: `close(x, x) = true` for all finite x
  - Symmetry: `close(x, y) = close(y, x)` (both functions)
  - `close` implies `close_enough`: `close(x, y) → close_enough(x, y)`
  - Non-transitivity: exhibit concrete counterexample for `close`
  - Zero special case: `close(0, 0) = true`, and the `tolerance²` threshold for near-zero comparisons
  - Identity of indiscernibles (partial): `close(x, y) ∧ close(y, z) → close_enough(x, z)` (or refute)
- **Spec-to-impl ratio**: **High** — the spec is a few algebraic laws; the implementation has 4 branches (equality shortcut, zero case, both-sided vs one-sided tolerance)
- **Proof tractability**: Moderate. Requires reasoning about absolute values and real inequalities. `linarith` and `norm_num` should handle most cases. The non-transitivity proof is interesting.
- **Approximations**: Model over `ℝ` with rational ε. The C++ uses `QL_EPSILON` (machine epsilon); Lean can axiomatise this as a positive real constant.

### 10. Black Formula (Option Pricing) — **HIGH VALUE, COMPOSES WITH EXISTING**

- **Files**: `ql/pricingengines/blackformula.hpp` (~424 lines), `ql/pricingengines/blackformula.cpp` (~972 lines)
- **Core function**: `blackFormula(Option::Type, strike, forward, stdDev, discount, displacement)` (~30 lines of core logic)
- **What it does**: Implements the Black 1976 closed-form option pricing formula using the cumulative normal distribution
- **Properties to verify**:
  - Put-call parity: `blackFormula(Call,...) - blackFormula(Put,...) = discount * (forward - strike)`
  - Non-negativity: result ≥ 0 for all valid inputs
  - Boundary at stdDev=0: `max(sign*(forward-strike), 0) * discount`
  - Monotonicity in stdDev: price increases with volatility (positive strike)
  - ATM symmetry: call = put when strike = forward (displacement=0)
- **Spec-to-impl ratio**: **High** — the mathematical spec is a single equation; the implementation adds displacement handling, edge cases, CDF calls
- **Proof tractability**: High — pure function, no state, no loops. Composes directly with already-verified `NormalDistribution`. Put-call parity is algebraically provable from the definition
- **Approximations**: Model over ℝ with Mathlib CDF. The C++ uses Abramowitz–Stegun polynomial approximation for CDF.
- **Why excellent**: Canonical finance FV target. Highest financial importance. Small core (~30 LOC), closed-form spec, rich algebraic properties.

### 11. Matrix Operations (Linear Algebra) — **ALGEBRAIC PROPERTIES**

- **Files**: `ql/math/matrix.hpp` (~755 lines), `ql/math/matrix.cpp` (~103 lines)
- **Key operations**: `operator+`, `operator-`, `operator*` (matrix×matrix, matrix×vector), `transpose`
- **Properties to verify**:
  - Commutativity of addition: `A + B = B + A`
  - Associativity of multiplication: `(A * B) * C = A * (B * C)`
  - Transpose involution: `transpose(transpose(A)) = A`
  - Distributivity: `A * (B + C) = A*B + A*C`
  - Identity matrix: `I * A = A`
- **Spec-to-impl ratio**: **High** — algebraic laws are trivial to state; implementation involves iterator arithmetic, move semantics, step iterators
- **Proof tractability**: Medium — requires induction over matrix dimensions. Bounded-size verification tractable
- **Approximations**: Model as `Array (Array ℚ)` or Mathlib `Matrix`

### 12. NewtonSafe (Bracketed Newton Solver) — **EXTENDS BISECTION**

- **File**: `ql/math/solvers1d/newtonsafe.hpp` (~114 lines, single file)
- **Core function**: `solveImpl(f, xAccuracy)` (~50 lines)
- **Properties to verify**:
  - Bracket maintenance: `xl ≤ root ≤ xh` loop invariant
  - Sign invariant: `f(xl) < 0` and `f(xh) > 0` throughout
  - Convergence criterion: on return, `|dx| < xAccuracy`
  - Bracket narrowing: `(xh - xl)` non-increasing each iteration
  - Bisection fallback correctness: when Newton step exits bracket, reverts to bisection
- **Spec-to-impl ratio**: **Medium-High** — the spec (root within tolerance, bracket maintained) is simpler than the hybrid Newton/bisection logic
- **Proof tractability**: High — single self-contained file, 50 LOC core. Directly analogous to already-verified `Bisection`; proof infrastructure reusable
- **Approximations**: Model with fuel-bounded recursion over ℚ, same as Bisection

## Critique-Driven Adjustments (Run 33)

Based on the latest critique (Run 30), we incorporated the following:
- **Cross-target composition**: The critique flagged the absence of cross-target theorems as a high-priority gap. The Black Formula target naturally addresses this — it composes InterestRate discounting with NormalDistribution CDF.
- **NewtonSafe**: Extends the successful Bisection verification to a more complex hybrid algorithm with richer proof obligations.
- **Deprioritised**: Schedule generation — while bug-prone, the spec is nearly as complex as the implementation (low ratio), making it a weaker FV target than Black Formula or NewtonSafe.

## Tool Choice Rationale

Lean 4 + Mathlib is chosen because:
- Rich real analysis library (exp, log, pow, derivatives, integrals)
- Strong automation (omega, linarith, norm_num, simp, decide)
- Active community and growing financial mathematics library
- Good IDE support for iterative proof development

---

## New Targets Identified (Run 53, 2026-05-06)

### 13. Rounding — **HIGH PRIORITY**

- **Files**: `ql/math/rounding.hpp`, `ql/math/rounding.cpp` (~80 lines impl)
- **What it does**: Implements 5 rounding modes (None, Up, Down, Closest, Floor, Ceiling) following the OMG specification for financial rounding. Uses a lookup-table fast_pow10 and modf to separate integral/fractional parts.
- **Benefit**: Rounding correctness is critical in finance — incorrect rounding causes reconciliation failures and regulatory issues. Properties: idempotence, monotonicity, symmetry between Floor/Ceiling, bound properties (rounded value within one unit of precision).
- **Spec-to-implementation complexity ratio**: **High** — The spec is ~6 algebraic properties (idempotence, bounded error, monotonicity, mode relationships). The implementation is ~60 lines with bit-masking tricks, modf decomposition, and five case branches. The specification is obviously correct on inspection while the implementation has subtle edge-case potential.
- **Specification size**: ~40 Lean lines for types + 10-15 theorems
- **Proof tractability**: Good — properties are arithmetic and can be proved with `omega`/`linarith`/`norm_num` over rationals. Modelling over ℚ avoids floating-point complications.
- **Approximations needed**: Model over ℚ (or ℤ with scaled integers) rather than IEEE 754 doubles. The C++ uses `modf` and floating-point multiplication which introduces representability issues not modelled.
- **Approach**: Define rounding modes algebraically, prove key properties by case analysis on the mode enum and arithmetic reasoning.

### 14. PrimeNumbers — **MEDIUM PRIORITY**

- **Files**: `ql/math/primenumbers.hpp`, `ql/math/primenumbers.cpp` (~50 lines)
- **What it does**: Trial-division prime sieve. Lazily generates primes by testing odd candidates against known primes up to sqrt(n).
- **Benefit**: The algorithm is a classic FV target — correctness = "every returned value is prime" + "no primes are skipped". Mathlib already has `Nat.Prime` and related infrastructure.
- **Spec-to-implementation complexity ratio**: **High** — The spec is "get(n) returns the (n+1)-th prime number". The implementation manages mutable state, a static vector, and trial division with sqrt optimization.
- **Specification size**: ~20 Lean lines (mostly leveraging Mathlib's `Nat.Prime`)
- **Proof tractability**: Moderate — proving the trial division algorithm correct requires showing the loop invariant (all primes up to sqrt are tested). Bounded `decide` can verify specific outputs.
- **Approximations needed**: Model as a pure function (ignore memoisation/caching). The C++ uses `BigNatural` (unsigned long) which may overflow for very large indices — not modelled.
- **Approach**: Define `nthPrime : ℕ → ℕ` using Mathlib's prime infrastructure. State that the trial-division algorithm agrees with `nthPrime`. Use `decide`/`native_decide` for small cases, inductive invariant for general correctness.
