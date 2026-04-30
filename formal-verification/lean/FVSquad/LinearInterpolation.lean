/-
  FVSquad.LinearInterpolation — Lean 4 formal specification and implementation model
  for QuantLib's LinearInterpolation.

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  ## What is modelled
  - The pure mathematical interpolation: value, derivative, secondDerivative
  - Knot interpolation, constant-function, monotonicity preservation

  ## What is NOT modelled
  - The `locate` function (binary search) — we assume correct segment index
  - Floating-point arithmetic — we use exact rationals
  - Iterator/template machinery — we use arrays
  - Out-of-range extrapolation behaviour
  - Primitive/antiderivative (left for future work)
-/

import Mathlib.Tactic
import Mathlib.Order.MinMax

namespace FVSquad.LinearInterpolation

/-! ## Core operations using plain functions on arrays -/

/-- Compute slope of segment i given arrays xs, ys of equal length. -/
def slope (xs ys : Array ℚ) (i : ℕ) : ℚ :=
  let xi := xs.getD i 0
  let xi1 := xs.getD (i + 1) 0
  let yi := ys.getD i 0
  let yi1 := ys.getD (i + 1) 0
  if xi1 - xi = 0 then 0 else (yi1 - yi) / (xi1 - xi)

/-- Interpolated value at x, given that x falls in segment i. -/
def value (xs ys : Array ℚ) (i : ℕ) (x : ℚ) : ℚ :=
  let xi := xs.getD i 0
  let yi := ys.getD i 0
  yi + (x - xi) * slope xs ys i

/-- Derivative at x in segment i (piecewise constant). -/
def derivative (xs ys : Array ℚ) (i : ℕ) : ℚ :=
  slope xs ys i

/-- Second derivative is always zero for linear interpolation. -/
def secondDerivative (_xs _ys : Array ℚ) (_x : ℚ) : ℚ := 0

/-! ## Key properties -/

/-- Second derivative is always zero. -/
theorem second_derivative_zero (xs ys : Array ℚ) (x : ℚ) :
    secondDerivative xs ys x = 0 := by
  rfl

/-- Knot interpolation: evaluating at knot x[i] returns y[i]. -/
theorem knot_interpolation (xs ys : Array ℚ) (i : ℕ) :
    value xs ys i (xs.getD i 0) = ys.getD i 0 := by
  unfold value
  simp [sub_self, zero_mul, add_zero]

/-- Derivative equals slope. -/
theorem derivative_eq_slope (xs ys : Array ℚ) (i : ℕ) :
    derivative xs ys i = slope xs ys i := by
  rfl

/-- Constant function: if y[i] = y[i+1] = c, the slope is 0 and value is c. -/
theorem constant_slope (xs ys : Array ℚ) (i : ℕ) (c : ℚ)
    (hyi : ys.getD i 0 = c) (hyi1 : ys.getD (i + 1) 0 = c) :
    slope xs ys i = 0 := by
  unfold slope
  rw [hyi, hyi1]
  simp [sub_self, zero_div]

/-- Constant function: value is c everywhere in that segment. -/
theorem constant_value (xs ys : Array ℚ) (i : ℕ) (c : ℚ) (x : ℚ)
    (hyi : ys.getD i 0 = c) (hyi1 : ys.getD (i + 1) 0 = c) :
    value xs ys i x = c := by
  unfold value
  simp only []
  have hs : slope xs ys i = 0 := constant_slope xs ys i c hyi hyi1
  rw [hyi, hs, mul_zero, add_zero]

/-- Monotonicity: if slope ≥ 0 and a ≤ b, then value(a) ≤ value(b). -/
theorem monotone_nonneg_slope (xs ys : Array ℚ) (i : ℕ) (a b : ℚ)
    (hs : 0 ≤ slope xs ys i) (hab : a ≤ b) :
    value xs ys i a ≤ value xs ys i b := by
  unfold value
  have h : (a - xs.getD i 0) * slope xs ys i ≤ (b - xs.getD i 0) * slope xs ys i := by
    apply mul_le_mul_of_nonneg_right _ hs
    linarith
  linarith

/-- Anti-monotonicity: if slope ≤ 0 and a ≤ b, then value(a) ≥ value(b). -/
theorem antitone_nonpos_slope (xs ys : Array ℚ) (i : ℕ) (a b : ℚ)
    (hs : slope xs ys i ≤ 0) (hab : a ≤ b) :
    value xs ys i b ≤ value xs ys i a := by
  unfold value
  have h : (b - xs.getD i 0) * slope xs ys i ≤ (a - xs.getD i 0) * slope xs ys i := by
    apply mul_le_mul_of_nonpos_right _ hs
    linarith
  linarith

end FVSquad.LinearInterpolation
