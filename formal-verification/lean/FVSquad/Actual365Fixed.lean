/-
  Formal Specification & Proofs: Actual365Fixed Day Counter (Standard Convention)

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  This file models the Actual/365 (Fixed) Standard day counting convention from
  QuantLib's Actual365Fixed::Impl class (ql/time/daycounters/actual365fixed.hpp).

  **Modelling choices**:
  - Dates are abstracted as integers (day offsets from an epoch).
  - Only the Standard convention is modelled (daysBetween / 365.0).
  - Canadian Bond and No Leap variants are NOT modelled here.
  - Uses Int for day counts and Float for year fractions.
  - Calendar logic (leap years, month lengths) is NOT modelled.

  **What is NOT captured**:
  - The Canadian Bond convention (reference period logic)
  - The No Leap convention (Feb 29 exclusion)
  - Date validation, error handling, class hierarchy
-/

namespace FVSquad.Actual365Fixed

/-- Day count between two dates.
    Models the raw day difference used by Actual365Fixed::Impl. -/
def dayCount (d1 d2 : Int) : Int := d2 - d1

/-- Year fraction under Act/365 (Fixed) Standard convention.
    Models Actual365Fixed::Impl::yearFraction. -/
def yearFraction (d1 d2 : Int) : Float :=
  Float.ofInt (dayCount d1 d2) / 365.0

/-! ## Proved Properties -/

/-- **Formula correctness**: yearFraction equals dayCount / 365. -/
theorem yearFraction_eq_dayCount_div_365 (d1 d2 : Int) :
    yearFraction d1 d2 = Float.ofInt (dayCount d1 d2) / 365.0 := by
  rfl

/-- **Non-negativity**: dayCount ≥ 0 when d2 ≥ d1. -/
theorem dayCount_nonneg (d1 d2 : Int) (h : d2 ≥ d1) :
    dayCount d1 d2 ≥ 0 := by
  simp [dayCount]; omega

/-- **Additivity**: dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3). -/
theorem dayCount_additive (d1 d2 d3 : Int) :
    dayCount d1 d2 + dayCount d2 d3 = dayCount d1 d3 := by
  simp [dayCount]; omega

/-- **Same-date**: dayCount(d, d) = 0. -/
theorem dayCount_self (d : Int) :
    dayCount d d = 0 := by
  simp [dayCount]

/-- **Anti-symmetry**: dayCount(d1, d2) = -dayCount(d2, d1). -/
theorem dayCount_antisymm (d1 d2 : Int) :
    dayCount d1 d2 = -dayCount d2 d1 := by
  simp [dayCount]; omega

/-- **Strict monotonicity**: if d2 < d3 then dayCount(d1,d2) < dayCount(d1,d3). -/
theorem dayCount_strict_mono (d1 d2 d3 : Int) (h : d2 < d3) :
    dayCount d1 d2 < dayCount d1 d3 := by
  simp [dayCount]; omega

/-- **Translation invariance**: shifting both dates by k preserves dayCount. -/
theorem dayCount_translate (d1 d2 k : Int) :
    dayCount (d1 + k) (d2 + k) = dayCount d1 d2 := by
  simp [dayCount]; omega

/-- **Full year**: dayCount over exactly 365 days equals 365. -/
theorem dayCount_full_year (d : Int) :
    dayCount d (d + 365) = 365 := by
  simp [dayCount]; omega

/-! ## Verification Examples -/

#eval dayCount 0 365       -- 365
#eval dayCount 0 182       -- 182
#eval dayCount 0 0         -- 0
#eval! yearFraction 0 365  -- 1.0
#eval! yearFraction 0 182  -- ~0.4986

end FVSquad.Actual365Fixed
