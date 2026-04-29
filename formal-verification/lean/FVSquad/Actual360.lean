/-
  Formal Specification: Actual360 Day Counter

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  This file models the Actual/360 day counting convention from QuantLib's
  Actual360 class (ql/time/daycounters/actual360.hpp).

  **Modelling choices**:
  - Dates are abstracted as integers (day offsets from an epoch).
    The only operation needed is subtraction to get day count.
  - The `includeLastDay` flag is modelled as a Bool parameter.
  - Uses Int for day counts and Float for year fractions.
  - Calendar logic (leap years, month lengths) is NOT modelled —
    we reason about the day-count-to-year-fraction formula only.
-/

namespace FVSquad.Actual360

-- Dates are represented as Int (day offsets from epoch).
-- We use Int directly rather than an abbrev so that omega works seamlessly.

/-- Day count between two dates, optionally including the last day.
    Models Actual360::Impl::dayCount in QuantLib. -/
def dayCount (d1 d2 : Int) (includeLastDay : Bool := false) : Int :=
  (d2 - d1) + if includeLastDay then 1 else 0

/-- Year fraction under Act/360 convention.
    Models Actual360::Impl::yearFraction in QuantLib. -/
def yearFraction (d1 d2 : Int) (includeLastDay : Bool := false) : Float :=
  Float.ofInt (dayCount d1 d2 includeLastDay) / 360.0

/-! ## Key Properties (Theorem Statements)

  Proofs are deferred with `sorry` — to be completed in Task 5.
-/

/-- **Formula correctness**: yearFraction equals dayCount / 360.
    This is essentially the definition, but states the key invariant. -/
theorem yearFraction_eq_dayCount_div_360 (d1 d2 : Int) (incl : Bool) :
    yearFraction d1 d2 incl = Float.ofInt (dayCount d1 d2 incl) / 360.0 := by
  rfl

/-- **Non-negativity**: dayCount ≥ 0 when d2 ≥ d1 and includeLastDay = false. -/
theorem dayCount_nonneg (d1 d2 : Int) (h : d2 ≥ d1) :
    dayCount d1 d2 false ≥ 0 := by
  simp [dayCount]; omega

/-- **Non-negativity with includeLastDay**: dayCount ≥ 1 when d2 ≥ d1. -/
theorem dayCount_pos_includeLastDay (d1 d2 : Int) (h : d2 ≥ d1) :
    dayCount d1 d2 true ≥ 1 := by
  simp [dayCount]; omega

/-- **Additivity** (without includeLastDay):
    dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3).
    This is the key algebraic property: (d2-d1) + (d3-d2) = (d3-d1). -/
theorem dayCount_additive (d1 d2 d3 : Int) :
    dayCount d1 d2 false + dayCount d2 d3 false = dayCount d1 d3 false := by
  simp [dayCount]; omega

/-- **Additivity fails with includeLastDay**: adding an extra day per segment
    means dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3) + 1. -/
theorem dayCount_includeLastDay_off_by_one (d1 d2 d3 : Int) :
    dayCount d1 d2 true + dayCount d2 d3 true =
    dayCount d1 d3 true + 1 := by
  simp [dayCount]; omega

/-- **Same-date**: dayCount(d, d) = 0 without includeLastDay. -/
theorem dayCount_self (d : Int) :
    dayCount d d false = 0 := by
  simp [dayCount]

/-- **Same-date with includeLastDay**: dayCount(d, d) = 1. -/
theorem dayCount_self_includeLastDay (d : Int) :
    dayCount d d true = 1 := by
  simp [dayCount]

/-- **Anti-symmetry**: dayCount(d1, d2) = -dayCount(d2, d1) without includeLastDay. -/
theorem dayCount_antisymm (d1 d2 : Int) :
    dayCount d1 d2 false = -dayCount d2 d1 false := by
  simp [dayCount]; omega

/-! ## Verification Examples -/

#eval dayCount 0 182 false      -- 182
#eval dayCount 0 182 true       -- 183
#eval dayCount 0 0 false        -- 0
#eval dayCount 0 0 true         -- 1
#eval! yearFraction 0 182 false  -- ~0.5056
#eval! yearFraction 0 360 false  -- 1.0

end FVSquad.Actual360
