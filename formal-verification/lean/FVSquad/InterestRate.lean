/-
  Formal Specification: InterestRate (compoundFactor / impliedRate)

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  This file models the interest rate compounding algebra from QuantLib's
  InterestRate class (ql/interestrate.hpp, ql/interestrate.cpp).

  **Modelling choices**:
  - Uses Float as a stand-in for real numbers (Lean stdlib, no Mathlib).
    A full verification would use exact reals from Mathlib.
  - Day counting is abstracted: we take time `t` as a nonneg rational/real.
  - Error handling (QL_REQUIRE) is modelled via Option types.
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

/-- Frequency as a positive rational represented as a natural number. -/
def Frequency.toFloat (f : Frequency) : Float := f.toNat.toFloat

/-- An interest rate with its compounding convention and optional frequency. -/
structure Rate where
  r : Float
  comp : Compounding
  freq : Option Frequency  -- None for Simple/Continuous
  deriving Repr

/-! ## Compound Factor

  Models `InterestRate::compoundFactor(Time t)` from ql/interestrate.cpp.

  For each compounding mode:
  - Simple:                 1 + r·t
  - Compounded:             (1 + r/n)^(n·t)
  - Continuous:             e^(r·t)
  - SimpleThenCompounded:   Simple if t ≤ 1/n, else Compounded
  - CompoundedThenSimple:   Compounded if t ≤ 1/n, else Simple
-/

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
    | _, none => none  -- frequency required but missing

/-! ## Implied Rate

  Models `InterestRate::impliedRate(compound, dc, comp, freq, t)`.
  Given a compound factor, recover the rate that produces it.
-/

/-- Implied rate for Simple compounding: r = (compound - 1) / t -/
def impliedSimple (compound t : Float) : Float := (compound - 1.0) / t

/-- Implied rate for Compounded mode: r = (compound^(1/(n·t)) - 1) · n -/
def impliedCompounded (compound t n : Float) : Float :=
  (compound ^ (1.0 / (n * t)) - 1.0) * n

/-- Implied rate for Continuous mode: r = ln(compound) / t -/
def impliedContinuous (compound t : Float) : Float :=
  Float.log compound / t

/-- Compute the implied rate, returning none if preconditions fail.
    Preconditions: compound > 0, and if compound ≠ 1 then t > 0. -/
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

/-! ## Key Properties (Theorem Statements)

  These are the formal statements of correctness properties from the informal spec.
  Proofs are deferred with `sorry` — to be completed in Task 5.
-/

/-- **Identity at t=0**: compoundFactor returns 1 when t = 0, for all modes.
    This corresponds to the C++ behaviour: all branches yield 1 when t=0. -/
theorem compoundFactor_zero_time (rate : Rate)
    (hfreq : rate.comp = .Simple ∨ rate.comp = .Continuous ∨ rate.freq.isSome) :
    compoundFactor rate 0.0 = some 1.0 := by
  sorry

/-- **Identity at r=0**: compoundFactor returns 1 when r = 0, for all t ≥ 0.
    Simple: 1 + 0·t = 1. Compounded: (1+0)^(n·t) = 1. Continuous: e^0 = 1. -/
theorem compoundFactor_zero_rate (comp : Compounding) (freq : Option Frequency) (t : Float)
    (ht : t ≥ 0.0) (hfreq : comp = .Simple ∨ comp = .Continuous ∨ freq.isSome) :
    compoundFactor ⟨0.0, comp, freq⟩ t = some 1.0 := by
  sorry

/-- **Positivity of continuous compounding**: e^(r·t) > 0 for all r, t. -/
theorem compoundContinuous_pos (r t : Float) :
    compoundContinuous r t > 0.0 := by
  sorry

/-- **Simple compounding round-trip**: impliedRate inverts compoundFactor
    for Simple compounding when t > 0. -/
theorem simple_roundtrip (r t : Float) (ht : t > 0.0) :
    impliedSimple (compoundSimple r t) t = r := by
  sorry

/-- **Continuous compounding round-trip**: impliedRate inverts compoundFactor
    for Continuous compounding when t > 0. -/
theorem continuous_roundtrip (r t : Float) (ht : t > 0.0) :
    impliedContinuous (compoundContinuous r t) t = r := by
  sorry

/-- **Compounded round-trip**: impliedRate inverts compoundFactor
    for Compounded mode when t > 0 and n > 0. -/
theorem compounded_roundtrip (r t n : Float) (ht : t > 0.0) (hn : n > 0.0)
    (hr : 1.0 + r / n > 0.0) :
    impliedCompounded (compoundCompounded r t n) t n = r := by
  sorry

/-! ## Verification Examples

  Concrete test cases from the informal spec to validate the model. -/

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
