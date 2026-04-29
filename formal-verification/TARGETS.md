# Formal Verification Targets — QuantLib

🔬 *Lean Squad — automated formal verification targets for `dsyme/QuantLib`.*

## Last Updated
- **Date**: 2026-04-29 17:05 UTC
- **Commit**: `8acbdd996`

## Prioritised Target List

### 1. InterestRate Compounding Algebra ⭐ Highest Priority

| Field | Value |
|-------|-------|
| **File** | `ql/interestrate.hpp`, `ql/interestrate.cpp` |
| **Functions** | `compoundFactor(Time)`, `discountFactor(Time)`, `impliedRate(Real, ...)` |
| **Phase** | 1 — Research complete |
| **Impl lines** | ~168 (cpp) |
| **Spec-to-impl ratio** | **High** — correctness captured by 3–4 algebraic laws; implementation has 6 compounding modes with complex case analysis |

**Properties to verify**:
- **Round-trip**: `impliedRate(compoundFactor(r, t), t) = r` for each compounding mode
- **Positivity**: `compoundFactor(t) > 0` for all valid `t ≥ 0`
- **Monotonicity**: `compoundFactor` is monotone increasing in both `r` (rate) and `t` (time) for positive rates
- **Identity**: `compoundFactor(0) = 1` for all compounding modes
- **Inverse relationship**: `discountFactor(t) = 1 / compoundFactor(t)`

**Benefit**: The round-trip property between `compoundFactor` and `impliedRate` is the core algebraic identity that all financial rate conversions depend on. A bug here would propagate to every pricing engine. The spec is ~5 clean equations; the implementation is ~100 lines of case analysis across 6 modes.

**Approach**: Model each compounding mode as a Lean function over `ℝ`. Use Mathlib's `Real.exp`, `Real.rpow`, and field arithmetic. Prove round-trip algebraically. Monotonicity via `Monotone` from Mathlib.

**Proof tractability**: Medium. Round-trip for Simple/Continuous modes should be straightforward algebra. Compounded mode requires reasoning about `rpow` inverses. SimpleThenCompounded/CompoundedThenSimple involve piecewise definitions.

**Approximations**: Model uses exact real arithmetic (no floating-point). Error paths and null checks are omitted.

---

### 2. Actual/360 Day Counter

| Field | Value |
|-------|-------|
| **File** | `ql/time/daycounters/actual360.hpp` |
| **Functions** | `dayCount(Date, Date)`, `yearFraction(Date, Date, ...)` |
| **Phase** | 1 — Research complete |
| **Impl lines** | ~67 (header-only) |
| **Spec-to-impl ratio** | **High** — spec is a single formula: `(d2 - d1) / 360`; implementation adds includeLastDay flag |

**Properties to verify**:
- **Formula correctness**: `yearFraction(d1, d2) = dayCount(d1, d2) / 360.0`
- **Additivity**: `dayCount(d1, d2) + dayCount(d2, d3) = dayCount(d1, d3)`
- **Non-negativity**: `yearFraction(d1, d2) ≥ 0` when `d2 ≥ d1`
- **Consistency**: `yearFraction(d, d) = 0` (or 1/360 if includeLastDay)

**Benefit**: Day count conventions are foundational — every interest calculation depends on them. ISDA defines the formula precisely, making the spec authoritative.

**Approach**: Model dates as integers (serial numbers). Prove properties via integer/rational arithmetic (`omega`, `linarith`).

**Proof tractability**: Easy. Mostly integer arithmetic, decidable for concrete cases.

**Approximations**: Dates modelled as integers. Calendar effects ignored (not relevant for Act/360).

---

### 3. Thirty/360 Day Counter (US Convention)

| Field | Value |
|-------|-------|
| **File** | `ql/time/daycounters/thirty360.hpp`, `ql/time/daycounters/thirty360.cpp` |
| **Functions** | `US_Impl::dayCount(Date, Date)` |
| **Phase** | 1 — Research complete |
| **Impl lines** | ~143 (cpp) + ~140 (hpp) |
| **Spec-to-impl ratio** | **High** — ISDA formula is 1 equation with adjustment rules; implementation has complex date decomposition with February edge cases |

**Properties to verify**:
- **ISDA formula**: `dayCount = 360*(Y2-Y1) + 30*(M2-M1) + (D2-D1)` with adjustments
- **Consistency with Actual**: for dates exactly 30 days apart in a 30-day month, Thirty360 and Actual should agree
- **Additivity** (approximate): check whether `dayCount(d1,d2) + dayCount(d2,d3) ≈ dayCount(d1,d3)`

**Benefit**: 30/360 conventions are notoriously tricky (6 different conventions with subtle date adjustment rules). Formal verification can catch edge cases around February, month-end, and leap years.

**Approach**: Model the US convention's adjustment rules in Lean. Use case analysis over day/month decomposition.

**Proof tractability**: Medium-hard. Multiple cases from month-end adjustments. Bounded `decide` for specific date ranges could help.

**Approximations**: Focus on US convention only. Calendar/holiday effects omitted.

---

### 4. Normal Distribution CDF

| Field | Value |
|-------|-------|
| **File** | `ql/math/distributions/normaldistribution.hpp`, `.cpp` |
| **Functions** | `CumulativeNormalDistribution::operator()`, `InverseCumulativeNormal::standard_value` |
| **Phase** | 1 — Research complete |
| **Impl lines** | ~510 total |
| **Spec-to-impl ratio** | **Medium** — spec is the mathematical CDF integral; implementation uses polynomial approximation (Abramowitz & Stegun / Acklam) |

**Properties to verify**:
- **Range**: `0 ≤ CDF(x) ≤ 1` for all `x`
- **Monotonicity**: `CDF` is monotone increasing
- **Symmetry**: `CDF(-x) = 1 - CDF(x)` for standard normal
- **Round-trip**: `InverseCDF(CDF(x)) ≈ x` (within numerical tolerance)
- **Boundary values**: `CDF(-∞) → 0`, `CDF(+∞) → 1`

**Benefit**: The normal CDF is used throughout option pricing (Black-Scholes). Properties like monotonicity and range are safety-critical.

**Approach**: Model CDF abstractly using Mathlib's real analysis. Prove structural properties without modelling the polynomial approximation. The approximation correctness is better tested than proved.

**Proof tractability**: Easy for range/symmetry on abstract model. Hard for approximation accuracy bounds.

**Approximations**: Lean model would use the mathematical definition, not the polynomial approximation. This means proofs verify the *specification*, not the *numerical implementation*.

---

### 5. Linear Interpolation

| Field | Value |
|-------|-------|
| **File** | `ql/math/interpolations/linearinterpolation.hpp` |
| **Functions** | `LinearInterpolationImpl::value`, `update` |
| **Phase** | 1 — Research complete |
| **Impl lines** | ~113 |
| **Spec-to-impl ratio** | **High** — spec is "affine between adjacent points"; implementation manages sorted arrays, slope computation, boundary conditions |

**Properties to verify**:
- **Interpolation**: value at grid points equals the given y-value
- **Affine between points**: for `x` between `x_i` and `x_{i+1}`, result is `y_i + (x - x_i) * slope_i`
- **Continuity**: the interpolated function is continuous
- **Monotonicity preservation**: if input y-values are monotone, output is monotone

**Benefit**: Linear interpolation is used extensively in yield curve construction. Correctness at grid points and continuity are essential.

**Approach**: Model as a function on sorted lists of (x, y) pairs. Use Mathlib's `Monotone` and list operations.

**Proof tractability**: Medium. Grid-point correctness is easy. Monotonicity preservation requires case analysis over adjacent intervals.

**Approximations**: Iterator-based C++ template code modelled as list operations. Memory management and template mechanics omitted.

---

## Priority Ranking

| Rank | Target | Rationale |
|------|--------|-----------|
| 1 | InterestRate Compounding | Highest FV value: clean algebraic laws, complex implementation, foundational to all pricing |
| 2 | Actual/360 Day Counter | Simplest target, quick win, ISDA-defined spec |
| 3 | Linear Interpolation | High spec-to-impl ratio, widely used in curve construction |
| 4 | Thirty/360 Day Counter | High bug potential (edge cases), but more complex to formalise |
| 5 | Normal Distribution CDF | Important but proof of approximation accuracy is out of scope |
