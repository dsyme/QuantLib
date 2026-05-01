# Implementation Correspondence — QuantLib FV

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-05-01 08:57 UTC
- **Commit**: `24f82b4a5` (Run 32)

---

## Actual360

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `dayCount` | `Actual360::Impl::dayCount` | `ql/time/daycounters/actual360.hpp` L51 | **Exact** | Both compute `(d2 - d1) + (includeLastDay ? 1 : 0)`. Lean uses `Int`, C++ uses `Date::serial_type` (long). |
| `yearFraction` | `Actual360::Impl::yearFraction` | `ql/time/daycounters/actual360.hpp` L54–56 | **Exact** | Both compute `dayCount / 360.0`. Lean uses `Float`, C++ uses `double`. |

**Divergences**: None. The Lean model abstracts dates as `Int` (day offsets), which exactly matches the `d2 - d1` integer subtraction in the C++. The division by 360.0 is identical.

**Impact on proofs**: All 7 proved theorems (`dayCount_nonneg`, `dayCount_additive`, `dayCount_antisymm`, `dayCount_pos_includeLastDay`, `dayCount_includeLastDay_off_by_one`, `dayCount_self`, `dayCount_self_includeLastDay`) reason about the `Int` day-count formula, which is semantically identical to the C++. The proofs are sound.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/actual360/` — 19 point cases + ~2,900 sweep cases, all passing. See `formal-verification/tests/actual360/README.md` for details.

---

## InterestRate

### Exact (Rat) Model — used for proofs

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `compoundSimpleQ` | `compoundFactor` Simple case | `ql/interestrate.cpp` L51 | **Exact** | `1 + r*t` in both. Lean uses exact `Rat`, C++ uses `double`. |
| `impliedSimpleQ` | `impliedRate` Simple case | `ql/interestrate.cpp` L80 | **Exact** | `(compound - 1) / t` in both. |
| `compoundCompoundedQ` | `compoundFactor` Compounded case | `ql/interestrate.cpp` L53 | **Approximation** | C++ uses `std::pow(1+r/n, n*t)` with a real-valued exponent `freq_*t` (non-integer for fractional years). Lean Rat model restricts to `Nat` exponent `periods`, so it is only valid when `n*t` is a natural number. For fractional compounding periods the Lean model diverges. |

**Divergences (Rat model)**:
1. **Compounded exponent domain**: C++ uses `std::pow` with a `double` exponent (`freq_ * t`), which allows fractional compounding periods. The Lean `Rat` model uses `Nat` exponent, restricting to integer periods only. This is an intentional abstraction — the Lean proofs over `compoundCompoundedQ` are valid only for integer numbers of compounding periods.
2. **No continuous compounding**: The Rat model cannot express `exp(r*t)` without Mathlib's `Real`. There is no Rat counterpart for the Continuous case.
3. **No error handling**: C++ uses `QL_REQUIRE` to reject `t < 0` and null rates. The Rat model has no precondition enforcement — callers must supply valid inputs.

### Computational (Float) Model — used for executable verification

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `compoundSimple` | `compoundFactor` Simple | `ql/interestrate.cpp` L51 | **Exact** | `1.0 + r * t` in both. |
| `compoundCompounded` | `compoundFactor` Compounded | `ql/interestrate.cpp` L53 | **Abstraction** | Both compute `(1+r/n)^(n*t)`. Lean uses `Float.pow`, C++ uses `std::pow`. Results should match for finite non-NaN inputs. |
| `compoundContinuous` | `compoundFactor` Continuous | `ql/interestrate.cpp` L55 | **Abstraction** | Both compute `exp(r*t)`. Lean uses `Float.exp`, C++ uses `std::exp`. |
| `impliedSimple` | `impliedRate` Simple | `ql/interestrate.cpp` L80 | **Exact** | `(compound - 1.0) / t` in both. |
| `impliedCompounded` | `impliedRate` Compounded | `ql/interestrate.cpp` L83 | **Abstraction** | `(c^(1/(n*t)) - 1) * n` — same formula, different `pow` implementations. |
| `impliedContinuous` | `impliedRate` Continuous | `ql/interestrate.cpp` L86 | **Abstraction** | `log(c) / t` in both. |
| `compoundFactor` | `InterestRate::compoundFactor` | `ql/interestrate.cpp` L45–67 | **Abstraction** | Lean models all 5 compounding modes and returns `Option Float` (C++ uses exceptions). The hybrid modes (`SimpleThenCompounded`, `CompoundedThenSimple`) have matching threshold logic (`t ≤ 1/n`). |
| `impliedRate` | `InterestRate::impliedRate` | `ql/interestrate.cpp` L69–107 | **Abstraction** | Lean mirrors the C++ switch structure. Returns `Option Float` instead of throwing. Guard on `compound == 1.0` with `t ≥ 0` matches C++. |

**Divergences (Float model)**:
1. **NaN/Inf edge cases**: Lean's `Float.pow` and `Float.exp` may differ from `std::pow`/`std::exp` at IEEE 754 edge cases (NaN, ±Inf, negative base with non-integer exponent).
2. **Error handling model**: C++ throws via `QL_REQUIRE`; Lean returns `none`. The error conditions are equivalent: `t < 0`, missing frequency, `compound ≤ 0`.
3. **Day counter abstraction**: C++ takes `Date` objects and a `DayCounter`; Lean takes `Float` time directly. The day-counting layer is not modelled.

### Real (ℝ) Model — used for continuous compounding proofs

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `compoundContinuousR` | `compoundFactor` Continuous case | `ql/interestrate.cpp` L55 | **Exact** | Both compute `exp(r·t)`. Lean uses Mathlib's `Real.exp`, C++ uses `std::exp`. Over exact reals, semantics are identical. |
| `impliedContinuousR` | `impliedRate` Continuous case | `ql/interestrate.cpp` L92 | **Exact** | Both compute `log(compound)/t`. Lean uses Mathlib's `Real.log`, C++ uses `std::log`. |

**Divergences (Real model)**: None for the mathematical semantics. The Real model operates over Mathlib's `ℝ`, which represents exact real numbers — the formulas are mathematically identical to the C++. The only gap is that C++ uses IEEE 754 `double`, which introduces floating-point rounding; the Real model does not capture this.

### Impact on proofs

The **11 Rat-proved theorems** are fully valid:
- `simple_roundtrip_exact`, `simple_zero_time`, `simple_zero_rate`: exact correspondence for Simple compounding.
- `compounded_zero_periods`, `compounded_zero_rate`: valid for integer periods (the Nat restriction does not affect zero-period/zero-rate edge cases).
- `simple_additive_excess`, `simple_monotone_rate`: algebraic properties of `1 + r*t`, exact correspondence.
- `compounded_one_period`, `simple_pos`, `compounded_mul_periods`, `simple_time_scaling`: additional structural properties of Rat model.

The **2 Rat-proved theorems** (Runs 11–13):
- `compounded_pos`: positivity of `(1 + r/n)^k` when `1 + r/n > 0`, proved via `positivity`.
- `compounded_monotone_periods`: more periods ⇒ higher factor when `1 ≤ 1 + r/n`, proved via `gcongr`.

The **1 Rat-proved theorem** added in Run 13:
- `simple_monotone_time`: longer time ⇒ higher factor for non-negative rate, proved via `Rat.mul_le_mul_of_nonneg_left`.

The **5 Real-proved theorems** (from prior runs) use Mathlib and are fully valid:
- `compoundContinuousR_pos`: `exp(r·t) > 0` — proved via `Real.exp_pos`.
- `continuousR_roundtrip`: `log(exp(r·t))/t = r` — proved via `Real.log_exp`.
- `continuousR_zero_time`, `continuousR_zero_rate`: identity elements — proved via `Real.exp_zero`.
- `continuousR_mul_periods`: `exp(r·(s+t)) = exp(r·s)·exp(r·t)` — proved via `Real.exp_add`.

The **6 Real-proved theorems** added in Runs 11–13:
- `continuousR_monotone_rate`: higher rate ⇒ higher compound factor for `t ≥ 0` — proved via `Real.exp_le_exp_of_le`.
- `continuousR_monotone_time`: longer time ⇒ higher compound factor for `r ≥ 0` — proved via `Real.exp_le_exp_of_le`.
- `continuousR_discount`: `1/exp(r·t) = exp(−r·t)` — proved via `Real.exp_neg`. This validates the `discountFactor = 1/compoundFactor` identity.
- `continuousR_gt_one`: `exp(r·t) > 1` when `r·t > 0` — proved via `Real.one_lt_exp_iff`.
- `continuousR_ge_simple`: `exp(r·t) ≥ 1 + r·t` for all `r, t` — proved via `Real.add_one_le_exp`. This establishes that continuous compounding always dominates simple compounding.

The **3 sorry-guarded Float theorems** (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) remain unproved because `Float` lacks algebraic axioms. Their Real counterparts are now proved.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/interestrate/` — 1394 test cases covering compoundFactor (344 cases), impliedRate (240 cases), round-trip (432 cases), and monotonicity (378 cases), all passing. See `formal-verification/tests/interestrate/README.md` for details.

---

## Thirty360 (European Convention)

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `adjustDayEU` | `EU_Impl::dayCount` (inline) | `ql/time/daycounters/thirty360.cpp` L93–94 | **Exact** | Both cap day at 30: C++ `if (dd == 31) dd = 30`, Lean `if d ≥ 31 then 30 else d`. Semantically identical for valid days (1–31). |
| `dayCountEU` | `Thirty360::EU_Impl::dayCount` | `ql/time/daycounters/thirty360.cpp` L87–97 | **Exact** | Both compute `360*(Y2-Y1) + 30*(M2-M1) + (D2'-D1')` after adjustment. Lean uses `Int`, C++ uses `Day`/`Month`/`Year` (all integer types). |
| `yearFractionEU` | `DayCounter::yearFraction` | `ql/time/daycounter.hpp` (base class) | **Exact** | Both compute `dayCount / 360`. Lean uses `ℚ` (exact rational), C++ uses `double`. |

**Divergences**: None for the European convention. The Lean model:
1. Uses `SimpleDate` (year, month, day as `Int`) instead of QuantLib's `Date` class. This is a simplification — QuantLib's `Date` validates calendrical correctness, while Lean accepts any `Int` triple. All proofs assume valid date components (day 1–31, month 1–12).
2. Uses the condition `d ≥ 31` rather than `d == 31`. For valid days (1–31), these are equivalent. The Lean form is slightly more defensive (handles impossible day=32+) but identical for valid inputs.
3. Does not model other conventions (US, ISMA, Italian, ISDA, NASD) — only European/30E/360.

**Impact on proofs**: All 9 proved theorems (`same_date_zero`, `yearfrac_eq_daycount_div_360`, `antisymmetry`, `full_year`, `full_month`, `adjust_idempotent`, `adjust_le_30`, `bounded_same_month`, `additivity_normal_days`) reason over the exact same formula as the C++. The proofs are sound for valid date inputs.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/thirty360/` — 575 test cases (Route B, Python reference implementation), all passing. See `formal-verification/tests/thirty360/README.md` for details.

---

## Factorial

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `factorial` | `Factorial::get(n)` | `ql/math/factorial.cpp` L49–53 | **Abstraction** | Both compute n!. C++ uses a lookup table for n ≤ 27, then `exp(GammaFunction::logValue(n+1))` for larger n. Lean uses `Nat.factorial n` (exact natural number arithmetic). For n ≤ 27 the values are identical. For n > 27 the C++ uses floating-point gamma approximation; the Lean model gives the exact integer. |

**Divergences**:
1. **Numeric type**: Lean uses exact `ℕ` (arbitrary-precision natural numbers). C++ returns `Real` (double). For n ≤ 27, the double can represent factorials exactly (all values < 2^53). For n > 27, C++ uses the gamma function approximation which introduces floating-point error; the Lean model gives exact values.
2. **Gamma fallback not modelled**: The C++ path `std::exp(GammaFunction().logValue(i+1))` for n > 27 is not modelled. The Lean model uses the recursive mathematical definition for all n.
3. **`ln` function not modelled**: `Factorial::ln(n)` is not present in the Lean model.

**Impact on proofs**: All 10 proved theorems (`factorial_zero`, `factorial_one`, `factorial_succ`, `factorial_pos`, `factorial_mono`, `factorial_strict_mono`, `factorial_growth`, `factorial_table_spot_check`, `factorial_sum_ge_mul`, `factorial_even_div`) reason about the exact mathematical factorial. These properties hold for the C++ implementation on its valid domain (n ≤ 27 for exact table lookup). For n > 27, the algebraic properties still hold for the mathematical function, but floating-point rounding in the C++ may cause tiny deviations from exact integer values.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/factorial/` — 28 test cases (n=0..27, Route B, Python reference), all passing. See `formal-verification/tests/factorial/README.md` for details.

---

## NormalDistribution

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `gaussianPDF` | `NormalDistribution::operator()` | `ql/math/distributions/normaldistribution.hpp` | **Exact** | Both compute `(1/(σ√(2π))) · exp(-(x-μ)²/(2σ²))`. Lean uses Mathlib's `Real.exp` and `Real.sqrt`; C++ uses `std::exp` and `std::sqrt`. Over exact reals, semantics are identical. |
| `gaussianPDF_deriv` | `NormalDistribution::derivative` | `ql/math/distributions/normaldistribution.hpp` | **Exact** | Both compute `-(x-μ)/σ² · f(x)`. Same formula. |
| `gaussianCDF` | `CumulativeNormalDistribution::operator()` | `ql/math/distributions/normaldistribution.hpp` | **Abstraction** | Both compute `0.5 · (1 + erf((x-μ)/(σ√2)))`. Lean uses Mathlib's `Real.erf`; C++ uses `ErrorFunction::operator()` which is a polynomial approximation. |
| `GaussianCDF` (structure) | `CumulativeNormalDistribution` | N/A | **Abstraction** | Lean axiomatises the CDF via its mathematical properties (monotonicity, range [0,1], symmetry). The C++ class computes values numerically. |
| `GaussianInvCDF` (structure) | `InverseCumulativeNormal` | `ql/math/distributions/normaldistribution.hpp` | **Abstraction** | Lean axiomatises the inverse CDF. C++ uses the Acklam rational approximation with Halley refinement. |

**Divergences**:
1. **CDF numerical approximation**: The C++ `ErrorFunction` uses a polynomial approximation (Abramowitz & Stegun or similar). The Lean model uses exact `Real.erf`. For typical inputs they agree to ~15 digits; for extreme tail values (|x| > 37) the C++ uses an asymptotic expansion not modelled in Lean.
2. **InverseCDF not implemented**: Lean only axiomatises the inverse CDF properties; it does not model the Acklam coefficients or Halley refinement step.
3. **Floating-point vs exact reals**: All Lean definitions use Mathlib's `ℝ`. C++ uses `double`.
4. **Error handling**: C++ has `σ ≤ 0` guards via `QL_REQUIRE`. Lean definitions assume `σ > 0` as a hypothesis.
5. **Tail cutoff**: C++ uses `exp(-690)` as a floor for very small PDF values. Not modelled.

**Impact on proofs**: All 15 proved theorems reason over exact real-valued mathematics. They are valid for the mathematical function that the C++ approximates. The 1 `sorry` (`cdf_deriv_eq_pdf`) requires Mathlib's `HasDerivAt` for the erf composition — it is a correct statement awaiting tactic support.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/normaldistribution/` — 1082 test cases (Route B, Python/scipy reference), all passing. See `formal-verification/tests/normaldistribution/README.md` for details.

---

## Bisection

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `orient` | Orientation block in `solveImpl` | `ql/math/solvers1d/bisection.hpp` L55–60 | **Exact** | Both check `fxMin < 0` and set `dx = xMax - xMin, root = xMin` or `dx = xMin - xMax, root = xMax`. Lean uses `ℚ`, C++ uses `Real` (double). |
| `bisectStep` | Loop body in `solveImpl` | `ql/math/solvers1d/bisection.hpp` L61–67 | **Exact** | Both halve dx, compute midpoint, evaluate f, update root if `fMid ≤ 0`. Lean uses `≤ 0` matching C++'s `<= 0.0`. |
| `bisect` | While loop in `solveImpl` | `ql/math/solvers1d/bisection.hpp` L60–72 | **Abstraction** | Lean uses fuel-bounded recursion; C++ uses `evaluationNumber_ <= maxEvaluations_` loop. Lean termination check is `|dx| < accuracy`; C++ also checks `close(fMid, 0.0)` (modelled as exact zero check `f xMid = 0`). |
| `solve` | `Bisection::solveImpl` (full) | `ql/math/solvers1d/bisection.hpp` | **Abstraction** | Lean composes `orient` then `bisect`. Matches C++ control flow. |

**Divergences**:
1. **Numeric type**: Lean uses exact `ℚ` (rationals); C++ uses `double`. For rational inputs, the bisection semantics are identical. For irrational roots, C++ rounds at each step while Lean computes exactly.
2. **`close(fMid, 0.0)` modelling**: C++ uses a closeness function with relative/absolute tolerance. Lean models this as exact `fMid = 0` (more restrictive). This means the Lean model may iterate longer than C++ on inputs where C++ would accept a near-zero as zero.
3. **Evaluation counting**: C++ tracks `evaluationNumber_` and the final redundant `f(root_)` call. Lean ignores this bookkeeping.
4. **Termination**: C++ can throw `QL_FAIL`; Lean returns `none` when fuel is exhausted.
5. **Solver1D base class**: C++ inherits from `Solver1D<Bisection>` which provides bracket validation (`xMin_`, `xMax_`, `fxMin_`, `fxMax_`). Lean takes these as explicit parameters.

**Impact on proofs**: All 15 theorems/lemmas are proved with 0 sorry. The proved theorems cover step-level properties (`dx_halves_each_step`, `midpoint_in_bracket`, `midpoint_in_bracket_neg`, `orient_dx_magnitude`, `step_root_in_interval`), convergence (`dx_after_k_steps`, `abs_dx_bisectStep`, `abs_dx_after_k_steps`), termination (`bisect_terminates`, `iterateStep_succ_eq`), and accuracy guarantees (`bisect_accuracy`). All reason about structural/geometric properties of the bisection step that are identical between C++ and Lean.

**Validation evidence**: 22 runnable correspondence test cases in `formal-verification/tests/bisection/test_bisection.py`. Tests compare a Python/Fraction exact-rational solver (matching Lean `ℚ` semantics) against a Python/float solver (matching C++ `double` semantics) on linear, quadratic, cubic, edge-case, convergence-rate, and orientation test cases. All 22 pass with exact agreement between rational and float solvers. Run with: `cd formal-verification/tests/bisection && python3 test_bisection.py`.

---

## LinearInterpolation

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `slope` | `s_[i]` (precomputed in `update()`) | `ql/math/interpolations/linearinterpolation.hpp` L84 | **Exact** | Both compute `(y[i+1] - y[i]) / (x[i+1] - x[i])`. Lean uses `ℚ`, C++ uses `Real` (double). |
| `value` | `LinearInterpolationImpl::value` | `ql/math/interpolations/linearinterpolation.hpp` L90 | **Exact** | Both compute `y[i] + (x - x[i]) * s[i]`. Lean uses `ℚ`, C++ uses `Real` (double). |
| `derivative` | `LinearInterpolationImpl::derivative` | `ql/math/interpolations/linearinterpolation.hpp` L99 | **Exact** | Both return `s[i]` (the slope of the segment). |
| `secondDerivative` | `LinearInterpolationImpl::secondDerivative` | `ql/math/interpolations/linearinterpolation.hpp` L102 | **Exact** | Both return `0.0`. |

**Divergences**:
1. **Segment location**: The C++ `locate(x)` function performs binary search to find which segment `x` falls in. The Lean model takes segment index `i` as an explicit parameter — it does not model the binary search. Proofs assume the correct segment is provided.
2. **Out-of-bounds handling**: C++ uses `getD` with default 0; Lean uses `Array.getD` with default 0 — these are equivalent. The C++ version additionally has extrapolation/bounds-checking logic not modelled.
3. **Numeric type**: Lean uses exact rationals (`ℚ`), C++ uses `double`. For rational inputs, results are identical. For irrational inputs, C++ rounds; Lean cannot represent them.
4. **Primitive (integral)**: The C++ class also implements `primitive(x)` for antiderivatives. The Lean model does not include this — it is noted as future work.

**Impact on proofs**: All 7 proved theorems (`second_derivative_zero`, `knot_interpolation`, `derivative_eq_slope`, `constant_function`, `linear_function`, `monotone_preservation`, `value_bounded`) reason over the exact same pointwise formula as C++. The proofs are sound for valid inputs within a correctly identified segment.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/linearinterpolation/` — 12 test cases covering knot interpolation, midpoint interpolation, and derivative computation. See the test harness for details.

---

## Actual365Fixed (Standard Convention)

| Lean Definition | C++ Source | File / Line | Correspondence | Justification |
|----------------|-----------|-------------|----------------|---------------|
| `dayCount` | `Actual365Fixed::Impl::dayCount` | `ql/time/daycounters/actual365fixed.hpp` | **Exact** | Both compute `d2 - d1`. Lean uses `Int`, C++ uses `Date::serial_type` (long). |
| `yearFraction` | `Actual365Fixed::Impl::yearFraction` | `ql/time/daycounters/actual365fixed.hpp` | **Exact** | Both compute `dayCount / 365.0`. Lean uses `Float`, C++ uses `double`. |

**Divergences**: None for Standard convention. The Lean model abstracts dates as `Int` (day offsets), exactly matching the `d2 - d1` integer subtraction in C++. Division by 365.0 is identical.

**What is NOT modelled**: Canadian Bond convention (reference period logic), No Leap convention (Feb 29 exclusion). Only the Standard convention is modelled.

**Impact on proofs**: All 8 proved theorems (`yearFraction_eq_dayCount_div_365`, `dayCount_nonneg`, `dayCount_additive`, `dayCount_self`, `dayCount_antisymm`, `dayCount_strict_mono`, `dayCount_translate`, `dayCount_full_year`) reason about the `Int` day-count formula, which is semantically identical to the C++. The proofs are sound.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/actual365fixed/` — 11 point cases + 2,273 sweep cases (additivity, antisymmetry, translation invariance, full year, strict monotonicity), all 2,295 passing. See `formal-verification/tests/actual365fixed/README.md`.

---

## Known Mismatches

None identified. The Rat model's restriction to `Nat` exponents for compounded mode is a documented, intentional abstraction — not a mismatch. Proofs that rely on `compoundCompoundedQ` are valid only for integer compounding periods, which is clearly noted in theorem preconditions.
