/-
  Formal Specification: InterestRate (compoundFactor / impliedRate)

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  This file models the interest rate compounding algebra from QuantLib's
  InterestRate class (ql/interestrate.hpp, ql/interestrate.cpp).

  **Modelling choices**:
  - **Exact model** uses `Rat` (exact rationals) for provable algebraic properties.
    This captures the mathematical intent of the C++ formulas without floating-point noise.
  - **Computational model** uses `Float` for executable verification examples.
  - Day counting is abstracted: we take time `t` as a nonneg rational.
  - Error handling (QL_REQUIRE) is modelled via Option types.
  - Continuous compounding (e^(r·t)) requires real `exp`/`log` which are not available
    in Lean stdlib for `Rat`. Those properties remain sorry-guarded pending Mathlib.
  - Compounded mode uses `Nat` exponent: `periods = n * t` must be a natural number,
    which is accurate for integer compounding periods.
  - IEEE 754 floating-point semantics are NOT modelled; we reason about
    the mathematical formulas only.
-/

namespace FVSquad.InterestRate

/-- Compounding conventions matching QuantLib's Compounding enum. -/
inductive Compounding where
  | Simple
  | Compounded
  | Continuous
  | SimpleThenCompounded
  | CompoundedThenSimple
  deriving Repr, BEq, DecidableEq

/-- Allowed compounding frequencies (times per year).
    QuantLib uses: Annual=1, Semiannual=2, etc. -/
inductive Frequency where
  | Annual       -- 1
  | Semiannual   -- 2
  | EveryFourthMonth -- 3
  | Quarterly    -- 4
  | Bimonthly    -- 6
  | Monthly      -- 12
  deriving Repr, BEq, DecidableEq

/-- Convert Frequency to its numeric value. -/
def Frequency.toNat : Frequency → Nat
  | .Annual => 1
  | .Semiannual => 2
  | .EveryFourthMonth => 3
  | .Quarterly => 4
  | .Bimonthly => 6
  | .Monthly => 12

/-- Frequency as a positive rational. -/
def Frequency.toRat (f : Frequency) : Rat := f.toNat

/-- Frequency as a Float for computational examples. -/
def Frequency.toFloat (f : Frequency) : Float := f.toNat.toFloat

/-! ## Exact Model (Rat)

  Algebraic model using exact rationals. Proofs are done over this model.
  Continuous compounding is excluded (requires transcendental functions).
-/

/-- Compound factor for Simple compounding: 1 + r·t -/
def compoundSimpleQ (r t : Rat) : Rat := 1 + r * t

/-- Implied rate for Simple compounding: r = (compound - 1) / t -/
def impliedSimpleQ (compound t : Rat) : Rat := (compound - 1) / t

/-- Compound factor for Compounded mode: (1 + r/n)^periods
    where periods is the number of compounding periods (a natural number). -/
def compoundCompoundedQ (r : Rat) (n : Rat) (periods : Nat) : Rat :=
  (1 + r / n) ^ periods

/-! ### Proved Properties (Exact Model)

  These theorems are fully machine-checked by Lean — no `sorry`.
-/

/-- **Simple round-trip**: impliedSimpleQ inverts compoundSimpleQ when t ≠ 0.
    Algebraically: ((1 + r·t) - 1) / t = r·t / t = r. -/
theorem simple_roundtrip_exact (r t : Rat) (ht : t ≠ 0) :
    impliedSimpleQ (compoundSimpleQ r t) t = r := by
  unfold impliedSimpleQ compoundSimpleQ
  have h1 : (1 : Rat) + r * t - 1 = r * t := by
    rw [Rat.add_comm]; exact Rat.add_sub_cancel
  rw [h1]
  exact Rat.mul_div_cancel ht

/-- **Simple zero-time identity**: compoundSimpleQ(r, 0) = 1 for all r.
    The compound factor at time zero is always 1. -/
theorem simple_zero_time (r : Rat) : compoundSimpleQ r 0 = 1 := by
  unfold compoundSimpleQ
  rw [Rat.mul_zero, Rat.add_zero]

/-- **Simple zero-rate identity**: compoundSimpleQ(0, t) = 1 for all t.
    A zero interest rate produces no growth. -/
theorem simple_zero_rate (t : Rat) : compoundSimpleQ 0 t = 1 := by
  unfold compoundSimpleQ
  rw [Rat.zero_mul, Rat.add_zero]

/-- **Compounded zero-time identity**: any rate compounded zero times yields 1.
    (1 + r/n)^0 = 1. -/
theorem compounded_zero_periods (r n : Rat) :
    compoundCompoundedQ r n 0 = 1 := by
  unfold compoundCompoundedQ
  exact Rat.pow_zero _

/-- Helper: 1^k = 1 for natural number exponents. -/
private theorem rat_one_pow (k : Nat) : (1 : Rat) ^ k = 1 := by
  induction k with
  | zero => exact Rat.pow_zero 1
  | succ n ih => rw [Rat.pow_succ, ih, Rat.mul_one]

/-- **Compounded zero-rate identity**: (1 + 0/n)^periods = 1 for all periods, n ≠ 0.
    A zero interest rate produces no growth regardless of compounding. -/
theorem compounded_zero_rate (n : Rat) (_hn : n ≠ 0) (periods : Nat) :
    compoundCompoundedQ 0 n periods = 1 := by
  unfold compoundCompoundedQ
  simp [Rat.div_def, Rat.zero_mul, Rat.add_zero]
  exact rat_one_pow periods

/-- **Simple linearity in time**: the excess over 1 scales linearly with time.
    compoundSimpleQ(r, s+t) - 1 = (compoundSimpleQ(r, s) - 1) + (compoundSimpleQ(r, t) - 1). -/
theorem simple_additive_excess (r s t : Rat) :
    compoundSimpleQ r (s + t) - 1 = (compoundSimpleQ r s - 1) + (compoundSimpleQ r t - 1) := by
  unfold compoundSimpleQ
  rw [Rat.mul_add]
  have lhs : (1 : Rat) + (r * s + r * t) - 1 = r * s + r * t := by
    rw [Rat.add_comm]; exact Rat.add_sub_cancel
  have rhs1 : (1 : Rat) + r * s - 1 = r * s := by
    rw [Rat.add_comm]; exact Rat.add_sub_cancel
  have rhs2 : (1 : Rat) + r * t - 1 = r * t := by
    rw [Rat.add_comm]; exact Rat.add_sub_cancel
  rw [lhs, rhs1, rhs2]

/-- **Simple monotonicity in rate**: for t ≥ 0, higher rate ⇒ higher compound factor.
    If r₁ ≤ r₂ and t ≥ 0, then compoundSimpleQ(r₁, t) ≤ compoundSimpleQ(r₂, t). -/
theorem simple_monotone_rate (r₁ r₂ t : Rat) (hr : r₁ ≤ r₂) (ht : 0 ≤ t) :
    compoundSimpleQ r₁ t ≤ compoundSimpleQ r₂ t := by
  unfold compoundSimpleQ
  have h : r₁ * t ≤ r₂ * t := Rat.mul_le_mul_of_nonneg_right hr ht
  exact (Rat.add_le_add_left (c := 1)).mpr h

/-! ## Computational Model (Float)

  Float-based model for executable verification examples.
  Algebraic proofs cannot be done over Float (no field axioms in stdlib).
-/

/-- An interest rate with its compounding convention and optional frequency. -/
structure Rate where
  r : Float
  comp : Compounding
  freq : Option Frequency
  deriving Repr

/-- Compound factor for Simple compounding: 1 + r·t -/
def compoundSimple (r t : Float) : Float := 1.0 + r * t

/-- Compound factor for Compounded mode: (1 + r/n)^(n·t) -/
def compoundCompounded (r t n : Float) : Float :=
  (1.0 + r / n) ^ (n * t)

/-- Compound factor for Continuous mode: e^(r·t) -/
def compoundContinuous (r t : Float) : Float :=
  Float.exp (r * t)

/-- Compute the compound factor, returning none if preconditions fail.
    Preconditions: t ≥ 0, and frequency must be provided for discrete modes. -/
def compoundFactor (rate : Rate) (t : Float) : Option Float :=
  if t < 0.0 then none
  else match rate.comp, rate.freq with
    | .Simple, _ => some (compoundSimple rate.r t)
    | .Continuous, _ => some (compoundContinuous rate.r t)
    | .Compounded, some f =>
        some (compoundCompounded rate.r t f.toFloat)
    | .SimpleThenCompounded, some f =>
        let n := f.toFloat
        if t <= 1.0 / n then some (compoundSimple rate.r t)
        else some (compoundCompounded rate.r t n)
    | .CompoundedThenSimple, some f =>
        let n := f.toFloat
        if t > 1.0 / n then some (compoundSimple rate.r t)
        else some (compoundCompounded rate.r t n)
    | _, none => none

/-- Implied rate for Simple compounding: r = (compound - 1) / t -/
def impliedSimple (compound t : Float) : Float := (compound - 1.0) / t

/-- Implied rate for Compounded mode: r = (compound^(1/(n·t)) - 1) · n -/
def impliedCompounded (compound t n : Float) : Float :=
  (compound ^ (1.0 / (n * t)) - 1.0) * n

/-- Implied rate for Continuous mode: r = ln(compound) / t -/
def impliedContinuous (compound t : Float) : Float :=
  Float.log compound / t

/-- Compute the implied rate, returning none if preconditions fail. -/
def impliedRate (compound : Float) (comp : Compounding) (freq : Option Frequency)
    (t : Float) : Option Float :=
  if compound <= 0.0 then none
  else if compound == 1.0 then
    if t >= 0.0 then some 0.0 else none
  else if t <= 0.0 then none
  else match comp, freq with
    | .Simple, _ => some (impliedSimple compound t)
    | .Continuous, _ => some (impliedContinuous compound t)
    | .Compounded, some f =>
        some (impliedCompounded compound t f.toFloat)
    | .SimpleThenCompounded, some f =>
        let n := f.toFloat
        if t <= 1.0 / n then some (impliedSimple compound t)
        else some (impliedCompounded compound t n)
    | .CompoundedThenSimple, some f =>
        let n := f.toFloat
        if t > 1.0 / n then some (impliedSimple compound t)
        else some (impliedCompounded compound t n)
    | _, none => none

/-! ## Sorry-guarded Properties (Float / Continuous)

  These properties require either Mathlib's `Real` type or `Float`-specific
  axioms that are not available in Lean 4 stdlib. They remain sorry-guarded
  as goals for future work.
-/

/-- **Positivity of continuous compounding**: e^(r·t) > 0 for all r, t.
    Requires: proof that Float.exp is positive (not in stdlib). -/
theorem compoundContinuous_pos (r t : Float) :
    compoundContinuous r t > 0.0 := by
  sorry  -- needs Float.exp_pos or Mathlib Real.exp_pos

/-- **Continuous round-trip**: ln(e^(r·t)) / t = r.
    Requires: Float.log_exp or Mathlib Real.log_exp. -/
theorem continuous_roundtrip (r t : Float) (ht : t > 0.0) :
    impliedContinuous (compoundContinuous r t) t = r := by
  sorry  -- needs Float.log (Float.exp x) = x (not in stdlib)

/-- **Compounded round-trip** (Float version): requires fractional exponents.
    The Rat version would require n-th roots which Rat does not support. -/
theorem compounded_roundtrip (r t n : Float) (ht : t > 0.0) (hn : n > 0.0)
    (hr : 1.0 + r / n > 0.0) :
    impliedCompounded (compoundCompounded r t n) t n = r := by
  sorry  -- needs (x^a)^(1/a) = x (not provable over Float in stdlib)

/-! ## Verification Examples -/

#eval compoundSimple 0.05 1.0          -- expected: 1.05
#eval compoundSimple 0.05 0.0          -- expected: 1.0
#eval compoundCompounded 0.05 1.0 2.0  -- expected: ~1.050625
#eval compoundContinuous 0.05 1.0      -- expected: ~1.05127

#eval compoundFactor ⟨0.05, .Simple, none⟩ 1.0           -- some 1.05
#eval compoundFactor ⟨0.05, .Continuous, none⟩ 0.0       -- some 1.0
#eval compoundFactor ⟨0.05, .Simple, none⟩ (-1.0)        -- none (t < 0)
#eval compoundFactor ⟨0.05, .Compounded, none⟩ 1.0       -- none (missing freq)

#eval impliedRate 1.05 .Simple none 1.0       -- some 0.05
#eval impliedRate 1.0 .Simple none 0.0        -- some 0.0
#eval impliedRate 0.0 .Simple none 1.0        -- none (compound ≤ 0)

end FVSquad.InterestRate
