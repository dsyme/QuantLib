# Implementation Correspondence — QuantLib FV

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-04-30 04:14 UTC
- **Commit**: `a367cac64`

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

### Impact on proofs

The 7 proved theorems operate on the **Rat model** and are fully valid:
- `simple_roundtrip_exact`, `simple_zero_time`, `simple_zero_rate`: exact correspondence for Simple compounding.
- `compounded_zero_periods`, `compounded_zero_rate`: valid for integer periods (the Nat restriction does not affect zero-period/zero-rate edge cases).
- `simple_additive_excess`, `simple_monotone_rate`: algebraic properties of `1 + r*t`, exact correspondence.

The 3 sorry-guarded theorems (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) operate on the **Float model** and would need `Float.exp`/`Float.log` axioms or Mathlib `Real` to prove.

**Validation evidence**: No runnable correspondence tests for InterestRate yet. Actual360 has validated correspondence tests. InterestRate correspondence tests are the next priority.

---

## Known Mismatches

None identified. The Rat model's restriction to `Nat` exponents for compounded mode is a documented, intentional abstraction — not a mismatch. Proofs that rely on `compoundCompoundedQ` are valid only for integer compounding periods, which is clearly noted in theorem preconditions.
