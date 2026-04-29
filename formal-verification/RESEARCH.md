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

## Tool Choice Rationale

Lean 4 + Mathlib is chosen because:
- Rich real analysis library (exp, log, pow, derivatives, integrals)
- Strong automation (omega, linarith, norm_num, simp, decide)
- Active community and growing financial mathematics library
- Good IDE support for iterative proof development
