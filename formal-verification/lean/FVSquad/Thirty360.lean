/-
  FVSquad.Thirty360 — Lean 4 formal specification and implementation model
  for QuantLib's Thirty360 day counter (European/30E/360 convention).

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  ## What is modelled
  - The European (30E/360) convention: the simplest and most algebraically clean
  - The core formula: 360*(Y2-Y1) + 30*(M2-M1) + (D2'-D1')
  - Day adjustment rules: cap days at 30

  ## What is NOT modelled
  - Other conventions (US, ISMA, Italian, ISDA, NASD) — future work
  - Actual calendar/date validation (we assume valid date components)
  - Floating-point — we use integers
  - The DayCounter base class / polymorphism machinery
-/

import Mathlib.Tactic

namespace FVSquad.Thirty360

/-! ## Date representation -/

/-- A simplified date as year, month (1-12), day (1-31). -/
structure SimpleDate where
  year : Int
  month : Int
  day : Int
  deriving Repr, DecidableEq

/-! ## European (30E/360) convention -/

/-- Adjust a day value per European convention: cap at 30. -/
def adjustDayEU (d : Int) : Int :=
  if d ≥ 31 then 30 else d

/-- Day count under European 30E/360 convention. -/
def dayCountEU (d1 d2 : SimpleDate) : Int :=
  let dd1 := adjustDayEU d1.day
  let dd2 := adjustDayEU d2.day
  360 * (d2.year - d1.year) + 30 * (d2.month - d1.month) + (dd2 - dd1)

/-- Year fraction under European 30E/360 convention (rational). -/
def yearFractionEU (d1 d2 : SimpleDate) : ℚ :=
  (dayCountEU d1 d2 : ℚ) / 360

/-! ## Key properties — European convention -/

/-- Same-date property: dayCount(d, d) = 0 for all dates. -/
theorem same_date_zero (d : SimpleDate) : dayCountEU d d = 0 := by
  unfold dayCountEU
  ring

/-- Year fraction is dayCount / 360 by construction. -/
theorem yearfrac_eq_daycount_div_360 (d1 d2 : SimpleDate) :
    yearFractionEU d1 d2 = (dayCountEU d1 d2 : ℚ) / 360 := by
  rfl

/-- Antisymmetry: dayCount(d1, d2) = -dayCount(d2, d1). -/
theorem antisymmetry (d1 d2 : SimpleDate) :
    dayCountEU d1 d2 = -(dayCountEU d2 d1) := by
  unfold dayCountEU
  ring

/-- Full year: for normal days (≤ 30), dates one year apart give 360. -/
theorem full_year (d : SimpleDate) (h : d.day ≤ 30) :
    dayCountEU d ⟨d.year + 1, d.month, d.day⟩ = 360 := by
  unfold dayCountEU adjustDayEU
  simp only []
  split_ifs <;> omega

/-- Full month: for days ≤ 28, dates one month apart give 30. -/
theorem full_month (d : SimpleDate) (h : d.day ≤ 28) :
    dayCountEU d ⟨d.year, d.month + 1, d.day⟩ = 30 := by
  unfold dayCountEU adjustDayEU
  simp only []
  split_ifs <;> omega

/-- Day adjustment is idempotent. -/
theorem adjust_idempotent (d : Int) : adjustDayEU (adjustDayEU d) = adjustDayEU d := by
  unfold adjustDayEU
  split_ifs <;> omega

/-- Adjusted day is at most 30. -/
theorem adjust_le_30 (d : Int) (h : d ≥ 1) : adjustDayEU d ≤ 30 := by
  unfold adjustDayEU
  split_ifs with hd
  · omega
  · omega

/-- Bounded within same month-year: |dayCount| ≤ 30 when same year and month. -/
theorem bounded_same_month (d1 d2 : SimpleDate)
    (hy : d1.year = d2.year) (hm : d1.month = d2.month)
    (h1 : 1 ≤ d1.day) (h1b : d1.day ≤ 31)
    (h2 : 1 ≤ d2.day) (h2b : d2.day ≤ 31) :
    (dayCountEU d1 d2).natAbs ≤ 30 := by
  unfold dayCountEU adjustDayEU
  simp only [hy, hm, sub_self, mul_zero, zero_add]
  split_ifs <;> omega

/-- Additivity: dayCount(d1, d2) + dayCount(d2, d3) = dayCount(d1, d3)
    when all days are ≤ 30 (adjustment is identity). -/
theorem additivity_normal_days (d1 d2 d3 : SimpleDate)
    (h1 : d1.day ≤ 30) (h2 : d2.day ≤ 30) (h3 : d3.day ≤ 30) :
    dayCountEU d1 d2 + dayCountEU d2 d3 = dayCountEU d1 d3 := by
  unfold dayCountEU adjustDayEU
  simp only []
  split_ifs <;> omega

/-- Day-31 equivalence: day 31 and day 30 give the same dayCount result
    because both are adjusted to 30. -/
theorem day31_eq_day30 (d1 d2 : SimpleDate) :
    dayCountEU ⟨d1.year, d1.month, 31⟩ d2 = dayCountEU ⟨d1.year, d1.month, 30⟩ d2 := by
  unfold dayCountEU adjustDayEU
  simp only []
  split_ifs <;> omega

/-- Monotonicity in year: later year ⇒ higher dayCount (same month/day ≤ 30). -/
theorem monotone_year (d : SimpleDate) (hd : d.day ≤ 30) (k : Int) (hk : k ≥ 0) :
    dayCountEU d ⟨d.year + k, d.month, d.day⟩ ≥ 0 := by
  unfold dayCountEU adjustDayEU
  simp only []
  split_ifs <;> omega

end FVSquad.Thirty360
