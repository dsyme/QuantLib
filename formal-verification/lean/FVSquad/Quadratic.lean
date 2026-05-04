/-
  Formal Verification: Quadratic Formula (QuantLib)

  🔬 Lean Squad — automated formal verification.

  Models: `ql/math/quadratic.hpp` and `ql/math/quadratic.cpp`
  A class representing ax² + bx + c with operations for evaluation,
  turning point, discriminant, and root finding.

  **Approximations**:
  - Uses ℝ (real numbers) instead of C++ `double`
  - Does not model the `bool roots(Real& x, Real& y)` output parameter pattern
  - sqrt is Mathlib's Real.sqrt (returns 0 for negative inputs)
-/

import Mathlib.Analysis.SpecificLimits.Basic
import Mathlib.Tactic

namespace FVSquad.Quadratic

/-! ## Types and Definitions -/

/-- A quadratic polynomial ax² + bx + c. -/
structure QuadPoly where
  a : ℝ
  b : ℝ
  c : ℝ
  ha : a ≠ 0

/-- Evaluate: a*x² + b*x + c. Models `quadratic::operator()`. -/
noncomputable def eval (q : QuadPoly) (x : ℝ) : ℝ :=
  q.a * x ^ 2 + q.b * x + q.c

/-- Turning point x-coordinate: -b/(2a). Models `quadratic::turningPoint()`. -/
noncomputable def turningPoint (q : QuadPoly) : ℝ :=
  -q.b / (2 * q.a)

/-- Value at the turning point. Models `quadratic::valueAtTurningPoint()`. -/
noncomputable def valueAtTurningPoint (q : QuadPoly) : ℝ :=
  eval q (turningPoint q)

/-- Discriminant: b² - 4ac. Models `quadratic::discriminant()`. -/
noncomputable def discriminant (q : QuadPoly) : ℝ :=
  q.b ^ 2 - 4 * q.a * q.c

/-- Smaller root: (-b - √Δ) / (2a). -/
noncomputable def rootSmall (q : QuadPoly) : ℝ :=
  (-q.b - Real.sqrt (discriminant q)) / (2 * q.a)

/-- Larger root: (-b + √Δ) / (2a). -/
noncomputable def rootLarge (q : QuadPoly) : ℝ :=
  (-q.b + Real.sqrt (discriminant q)) / (2 * q.a)

/-- Formal derivative: 2ax + b. -/
noncomputable def formalDeriv (q : QuadPoly) (x : ℝ) : ℝ :=
  2 * q.a * x + q.b

/-! ## Proved Theorems (11 proved, 2 sorry) -/

theorem eval_eq_horner (q : QuadPoly) (x : ℝ) :
    eval q x = x * (x * q.a + q.b) + q.c := by unfold eval; ring

theorem eval_zero (q : QuadPoly) : eval q 0 = q.c := by unfold eval; ring

theorem eval_one (q : QuadPoly) : eval q 1 = q.a + q.b + q.c := by unfold eval; ring

theorem eval_neg (q : QuadPoly) (x : ℝ) :
    eval q (-x) = q.a * x ^ 2 - q.b * x + q.c := by unfold eval; ring

theorem eval_sym (q : QuadPoly) (x : ℝ) :
    eval q x + eval q (-x) = 2 * (q.a * x ^ 2 + q.c) := by unfold eval; ring

theorem eval_antisym (q : QuadPoly) (x : ℝ) :
    eval q x - eval q (-x) = 2 * q.b * x := by unfold eval; ring

theorem eval_shift (q : QuadPoly) (x h : ℝ) :
    eval q (x + h) = eval q x + h * (2 * q.a * x + q.b + q.a * h) := by unfold eval; ring

theorem formalDeriv_at_turningPoint_zero (q : QuadPoly) :
    formalDeriv q (turningPoint q) = 0 := by
  simp only [formalDeriv, turningPoint]
  have ha : q.a ≠ 0 := q.ha
  field_simp
  ring

theorem valueAtTurningPoint_formula (q : QuadPoly) :
    valueAtTurningPoint q = q.c - q.b ^ 2 / (4 * q.a) := by
  unfold valueAtTurningPoint eval turningPoint
  have h2a : (2 : ℝ) * q.a ≠ 0 := mul_ne_zero two_ne_zero q.ha
  have h4a : (4 : ℝ) * q.a ≠ 0 := mul_ne_zero four_ne_zero q.ha
  field_simp; ring

theorem vieta_sum (q : QuadPoly) (_hd : discriminant q ≥ 0) :
    rootSmall q + rootLarge q = -q.b / q.a := by
  unfold rootSmall rootLarge
  have h2a : (2 : ℝ) * q.a ≠ 0 := mul_ne_zero two_ne_zero q.ha
  field_simp; ring

theorem double_root (q : QuadPoly) (hd : discriminant q = 0) :
    rootSmall q = turningPoint q ∧ rootLarge q = turningPoint q := by
  unfold rootSmall rootLarge turningPoint discriminant at *
  have hsqrt : Real.sqrt (q.b ^ 2 - 4 * q.a * q.c) = 0 := by
    rw [Real.sqrt_eq_zero (by linarith : q.b ^ 2 - 4 * q.a * q.c ≥ 0)]
    linarith
  simp [hsqrt]

/-- Root existence implies nonneg discriminant. -/
theorem root_implies_discriminant_nonneg (q : QuadPoly) (x : ℝ) (hx : eval q x = 0) :
    discriminant q ≥ 0 := by
  unfold eval at hx; unfold discriminant
  have h1 : q.c = -(q.a * x ^ 2 + q.b * x) := by linarith
  rw [h1]
  have : q.b ^ 2 - 4 * q.a * -(q.a * x ^ 2 + q.b * x) = (2 * q.a * x + q.b) ^ 2 := by ring
  linarith [sq_nonneg (2 * q.a * x + q.b)]

/-! ## Sorry-guarded theorems (root verification needs field_simp over division) -/

/-- rootLarge is a root when Δ ≥ 0.
    Sorry: requires clearing (2a)² denominator + nlinarith with sq_sqrt. -/
theorem eval_rootLarge_eq_zero (q : QuadPoly) (hd : discriminant q ≥ 0) :
    eval q (rootLarge q) = 0 := by
  unfold eval rootLarge discriminant at *
  have h2a : (2 : ℝ) * q.a ≠ 0 := mul_ne_zero two_ne_zero q.ha
  have hsq : Real.sqrt (q.b ^ 2 - 4 * q.a * q.c) ^ 2 = q.b ^ 2 - 4 * q.a * q.c :=
    Real.sq_sqrt hd
  sorry -- needs manual clearing of (2*a)^2 denominator

/-- rootSmall is a root when Δ ≥ 0. -/
theorem eval_rootSmall_eq_zero (q : QuadPoly) (hd : discriminant q ≥ 0) :
    eval q (rootSmall q) = 0 := by
  unfold eval rootSmall discriminant at *
  have h2a : (2 : ℝ) * q.a ≠ 0 := mul_ne_zero two_ne_zero q.ha
  have hsq : Real.sqrt (q.b ^ 2 - 4 * q.a * q.c) ^ 2 = q.b ^ 2 - 4 * q.a * q.c :=
    Real.sq_sqrt hd
  sorry -- needs manual clearing of (2*a)^2 denominator

end FVSquad.Quadratic
