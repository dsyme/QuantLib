/-
  FloatingPointClose.lean — Formal specification and implementation model
  for QuantLib's floating-point comparison functions (ql/math/comparison.hpp).

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  ## What is modelled

  We model `close` and `close_enough` over ℚ (rationals) with a rational
  tolerance parameter `ε ≥ 0`. The core semantics are:

    close(x, y, ε)        ≡ |x - y| ≤ ε·|x|  ∧  |x - y| ≤ ε·|y|
    close_enough(x, y, ε) ≡ |x - y| ≤ ε·|x|  ∨  |x - y| ≤ ε·|y|

  with special handling when x = 0 or y = 0:

    zero case: |x - y| ≤ ε²

  ## What is NOT modelled

  - IEEE 754 special values: NaN, ±∞, signed zeros, denormals
  - The `x == y` short-circuit (bitwise equality)
  - The strict inequality `<` vs `≤` for the zero case
    (C++ uses `<` for zero case; we use `≤` for cleaner proofs)
  - Machine epsilon scaling (`n * QL_EPSILON`); we use abstract `ε`
  - Floating-point rounding in intermediate computations
-/

import Mathlib.Tactic

namespace FVSquad.FloatingPointClose

/-! ## Core definitions -/

/-- `close x y ε` holds when `|x - y|` is within `ε` of both `|x|` and `|y|`.
    When either operand is zero, uses `ε²` as an absolute threshold. -/
def close (x y ε : ℚ) : Prop :=
  if x = 0 ∨ y = 0 then
    |x - y| ≤ ε ^ 2
  else
    |x - y| ≤ ε * |x| ∧ |x - y| ≤ ε * |y|

/-- `close_enough x y ε` holds when `|x - y|` is within `ε` of `|x|` or `|y|`.
    When either operand is zero, uses `ε²` as an absolute threshold. -/
def close_enough (x y ε : ℚ) : Prop :=
  if x = 0 ∨ y = 0 then
    |x - y| ≤ ε ^ 2
  else
    |x - y| ≤ ε * |x| ∨ |x - y| ≤ ε * |y|

/-- Boolean decision procedure for `close`. -/
instance : DecidablePred (fun (t : ℚ × ℚ × ℚ) => close t.1 t.2.1 t.2.2) := by
  intro ⟨x, y, ε⟩; unfold close; exact inferInstance

/-- Boolean decision procedure for `close_enough`. -/
instance : DecidablePred (fun (t : ℚ × ℚ × ℚ) => close_enough t.1 t.2.1 t.2.2) := by
  intro ⟨x, y, ε⟩; unfold close_enough; exact inferInstance

/-! ## Properties -/

/-- Reflexivity: `close x x ε` for any `x` and non-negative `ε`. -/
theorem close_refl (x ε : ℚ) (hε : 0 ≤ ε) : close x x ε := by
  unfold close
  split_ifs with h
  · rw [sub_self, abs_zero]; positivity
  · rw [sub_self, abs_zero]; exact ⟨by positivity, by positivity⟩

/-- Reflexivity for `close_enough`. -/
theorem close_enough_refl (x ε : ℚ) (hε : 0 ≤ ε) : close_enough x x ε := by
  unfold close_enough
  split_ifs with h
  · rw [sub_self, abs_zero]; positivity
  · rw [sub_self, abs_zero]; exact Or.inl (by positivity)

/-- Symmetry: `close x y ε ↔ close y x ε`. -/
theorem close_symm (x y ε : ℚ) : close x y ε ↔ close y x ε := by
  unfold close
  constructor <;> intro h
  all_goals {
    split_ifs at h ⊢ with h1 h2
    all_goals simp_all [abs_sub_comm]
  }

/-- Symmetry for `close_enough`. -/
theorem close_enough_symm (x y ε : ℚ) : close_enough x y ε ↔ close_enough y x ε := by
  unfold close_enough
  constructor <;> intro h
  all_goals {
    split_ifs at h ⊢ with h1 h2
    all_goals simp_all [abs_sub_comm]
    all_goals try exact h.symm
  }

/-- Implication: `close x y ε → close_enough x y ε`. -/
theorem close_implies_close_enough (x y ε : ℚ) :
    close x y ε → close_enough x y ε := by
  unfold close close_enough
  split
  · exact id
  · exact fun ⟨h1, _⟩ => Or.inl h1

/-- Monotonicity in tolerance for `close` (non-zero case). -/
theorem close_mono_tol {x y ε₁ ε₂ : ℚ} (hε : ε₁ ≤ ε₂)
    (hx : x ≠ 0) (hy : y ≠ 0) (hc : close x y ε₁) : close x y ε₂ := by
  unfold close at *
  simp [hx, hy] at *
  exact ⟨le_trans hc.1 (mul_le_mul_of_nonneg_right hε (abs_nonneg x)),
         le_trans hc.2 (mul_le_mul_of_nonneg_right hε (abs_nonneg y))⟩

/-- Monotonicity in tolerance for `close_enough` (non-zero case). -/
theorem close_enough_mono_tol {x y ε₁ ε₂ : ℚ} (hε : ε₁ ≤ ε₂)
    (hx : x ≠ 0) (hy : y ≠ 0) (hc : close_enough x y ε₁) :
    close_enough x y ε₂ := by
  unfold close_enough at *
  simp [hx, hy] at *
  cases hc with
  | inl h => exact Or.inl (le_trans h (mul_le_mul_of_nonneg_right hε (abs_nonneg x)))
  | inr h => exact Or.inr (le_trans h (mul_le_mul_of_nonneg_right hε (abs_nonneg y)))

/-- Zero tolerance: `close x y 0 ↔ x = y` (non-zero case). -/
theorem close_zero_tol {x y : ℚ} (hx : x ≠ 0) (hy : y ≠ 0) :
    close x y 0 ↔ x = y := by
  unfold close
  simp [hx, hy, zero_mul, abs_nonpos_iff, sub_eq_zero]

/-- Zero tolerance: `close_enough x y 0 ↔ x = y` (non-zero case). -/
theorem close_enough_zero_tol {x y : ℚ} (hx : x ≠ 0) (hy : y ≠ 0) :
    close_enough x y 0 ↔ x = y := by
  unfold close_enough
  simp [hx, hy, zero_mul, abs_nonpos_iff, sub_eq_zero]

/-- `close` is NOT transitive in general. -/
theorem close_not_transitive :
    ∃ (x y z ε : ℚ), close x y ε ∧ close y z ε ∧ ¬ close x z ε := by
  -- Witness: x=10, y=11, z=121/10, ε=1/10
  refine ⟨10, 11, 121/10, 1/10, ?_, ?_, ?_⟩
  · unfold close; simp; norm_num
  · unfold close; simp; norm_num
  · unfold close; simp; norm_num

/-- Monotonicity in tolerance for the zero case. -/
theorem close_mono_tol_zero {x y ε₁ ε₂ : ℚ} (hε₁ : 0 ≤ ε₁) (hε : ε₁ ≤ ε₂)
    (hzero : x = 0 ∨ y = 0) (hc : close x y ε₁) : close x y ε₂ := by
  unfold close at *
  simp [hzero] at *
  exact le_trans hc (pow_le_pow_left₀ hε₁ hε 2)

/-- `close_enough` is strictly weaker than `close`. -/
theorem close_enough_strictly_weaker :
    ∃ (x y ε : ℚ), close_enough x y ε ∧ ¬ close x y ε := by
  -- Witness: x=10, y=11, ε=1/11
  refine ⟨10, 11, 1/11, ?_, ?_⟩
  · unfold close_enough; simp; norm_num
  · unfold close; simp; norm_num

end FVSquad.FloatingPointClose
