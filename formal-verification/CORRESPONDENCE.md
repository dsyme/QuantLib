# Implementation Correspondence — QuantLib FV

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-04-29 20:30 UTC
- **Commit**: `07c6bfd98ddb`

---

## Actual360

| Lean Definition | C++ Source | Correspondence | Justification |
|----------------|-----------|----------------|---------------|
| `FVSquad.Actual360.dayCount` | `Actual360::Impl::dayCount` (`ql/time/daycounters/actual360.hpp#L47`) | **Exact** | Both compute `(d2 - d1) + (includeLastDay ? 1 : 0)`. Lean uses `Int`, C++ uses `Date::serial_type` (long). |
| `FVSquad.Actual360.yearFraction` | `Actual360::Impl::yearFraction` (`ql/time/daycounters/actual360.hpp#L50`) | **Exact** | Both compute `dayCount / 360.0`. Lean uses `Float`, C++ uses `double`. |

**Divergences**: None. The Lean model abstracts dates as `Int` (day offsets), which exactly matches the `d2 - d1` integer subtraction in the C++. The division by 360.0 is identical.

**Impact on proofs**: All 7 proved theorems (`dayCount_nonneg`, `dayCount_additive`, `dayCount_antisymm`, etc.) reason about the `Int` day-count formula, which is semantically identical to the C++. The proofs are sound.

**Validation evidence**: Runnable correspondence tests at `formal-verification/tests/actual360/` — 19 point cases + ~2,900 sweep cases, all passing. See `formal-verification/tests/actual360/README.md` for details.

---

## InterestRate

| Lean Definition | C++ Source | Correspondence | Justification |
|----------------|-----------|----------------|---------------|
| `FVSquad.InterestRate.compoundSimple` | `InterestRate::compoundFactor` Simple case (`ql/interestrate.cpp`) | **Exact** | `1 + r*t` in both. |
| `FVSquad.InterestRate.compoundCompounded` | `InterestRate::compoundFactor` Compounded case | **Abstraction** | Lean uses `Float.pow`; C++ uses `std::pow`. Semantically equivalent for finite inputs. |
| `FVSquad.InterestRate.compoundContinuous` | `InterestRate::compoundFactor` Continuous case | **Abstraction** | Lean uses `Float.exp`; C++ uses `std::exp`. |
| `FVSquad.InterestRate.impliedSimple` | `InterestRate::impliedRate` Simple case | **Exact** | `(compound - 1) / t` in both. |
| `FVSquad.InterestRate.impliedCompounded` | `InterestRate::impliedRate` Compounded case | **Abstraction** | `(c^(1/(n*t)) - 1) * n` — same formula, different `pow` implementations. |
| `FVSquad.InterestRate.impliedContinuous` | `InterestRate::impliedRate` Continuous case | **Abstraction** | `log(c) / t` in both. |

**Divergences**: The Lean model uses `Float` (IEEE 754 double via Lean runtime) which should match C++ `double` for finite values. However, Lean's `Float.pow` and `Float.exp` may have different NaN/Inf edge-case behaviour than `std::pow`/`std::exp`. The Lean model uses `Option` for error handling where C++ uses `QL_REQUIRE` exceptions.

**Impact on proofs**: The 6 sorry-guarded theorems reason about algebraic round-trip properties. If proved, they would hold for the mathematical formulas but may not account for floating-point rounding.

**Validation evidence**: No runnable correspondence tests yet. This is the next priority for Task 8.

---

## Known Mismatches

None identified.
