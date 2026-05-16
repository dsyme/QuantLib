/-
  Formal Verification: BernsteinPolynomial (QuantLib)
  🔬 Lean Squad — automated formal verification.

  Target: ql/math/bernsteinpolynomial.hpp
  Models: BernsteinPolynomial::get(i, n, x)

  Approximations:
  - Uses exact real arithmetic (ℝ) rather than IEEE 754 doubles
  - Does not model factorial overflow for large n
  - Precondition i ≤ n is required (no error handling modelled)
-/

import Mathlib.Data.Nat.Choose.Basic
import Mathlib.Data.Nat.Choose.Sum
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Tactic

namespace FVSquad.BernsteinPolynomial

open Finset BigOperators

/-! ## Implementation Model

  We model `BernsteinPolynomial::get(i, n, x)` as the standard Bernstein basis
  polynomial: B_{i,n}(x) = C(n, i) * x^i * (1-x)^(n-i).
-/

/-- The Bernstein basis polynomial B_{i,n}(x) = C(n,i) * x^i * (1-x)^(n-i). -/
noncomputable def bernstein (n i : ℕ) (x : ℝ) : ℝ :=
  (Nat.choose n i : ℝ) * x ^ i * (1 - x) ^ (n - i)

/-! ## Theorems -/

/-- Base case: B_{0,0}(x) = 1 for all x. -/
theorem bernstein_zero_zero (x : ℝ) : bernstein 0 0 x = 1 := by
  unfold bernstein
  simp

/-- Boundary: B_{0,n}(0) = 1. Only the first polynomial is nonzero at x=0. -/
theorem bernstein_zero_at_zero (n : ℕ) : bernstein n 0 0 = 1 := by
  unfold bernstein
  simp

/-- Boundary: B_{n,n}(1) = 1. Only the last polynomial is nonzero at x=1. -/
theorem bernstein_n_at_one (n : ℕ) : bernstein n n 1 = 1 := by
  unfold bernstein
  simp [Nat.sub_self, Nat.choose_self]

/-- Boundary: B_{i,n}(0) = 0 for i > 0. -/
theorem bernstein_at_zero (n i : ℕ) (hi : 0 < i) (hin : i ≤ n) :
    bernstein n i 0 = 0 := by
  unfold bernstein
  simp [zero_pow (Nat.pos_iff_ne_zero.mp hi)]

/-- Boundary: B_{i,n}(1) = 0 for i < n. -/
theorem bernstein_at_one (n i : ℕ) (hi : i < n) :
    bernstein n i 1 = 0 := by
  unfold bernstein
  have h : 0 < n - i := Nat.sub_pos_of_lt hi
  simp [zero_pow (Nat.pos_iff_ne_zero.mp h)]

/-- Symmetry: B_{i,n}(x) = B_{n-i,n}(1-x). -/
theorem bernstein_symmetry (n i : ℕ) (hin : i ≤ n) (x : ℝ) :
    bernstein n i x = bernstein n (n - i) (1 - x) := by
  unfold bernstein
  rw [Nat.choose_symm hin, Nat.sub_sub_self hin]
  simp only [sub_sub_cancel]
  ring

/-- Non-negativity: B_{i,n}(x) ≥ 0 for x ∈ [0, 1]. -/
theorem bernstein_nonneg (n i : ℕ) (hin : i ≤ n) (x : ℝ)
    (hx0 : 0 ≤ x) (hx1 : x ≤ 1) : 0 ≤ bernstein n i x := by
  unfold bernstein
  apply mul_nonneg
  · apply mul_nonneg
    · positivity
    · exact pow_nonneg hx0 i
  · exact pow_nonneg (by linarith) (n - i)

/-- Partition of unity: ∑_{i=0}^{n} B_{i,n}(x) = 1.
    Follows from the binomial theorem: (x + (1-x))^n = 1. -/
theorem bernstein_partition_of_unity (n : ℕ) (x : ℝ) :
    ∑ i ∈ range (n + 1), bernstein n i x = 1 := by
  unfold bernstein
  have hc : Commute x (1 - x) := Commute.all x (1 - x)
  have h := hc.add_pow n
  simp only [show x + (1 - x) = (1 : ℝ) from by ring, one_pow] at h
  convert h.symm using 1
  apply Finset.sum_congr rfl
  intro i _
  ring

/-- Recursion (de Casteljau): B_{i,n}(x) = (1-x)·B_{i,n-1}(x) + x·B_{i-1,n-1}(x).
    With appropriate boundary conventions for out-of-range indices. -/
theorem bernstein_recursion (n i : ℕ) (hn : 0 < n) (hi : 0 < i) (hin : i ≤ n)
    (x : ℝ) :
    bernstein n i x = (1 - x) * bernstein (n - 1) i x +
                      x * bernstein (n - 1) (i - 1) x := by
  simp only [bernstein]
  have h_pascal : (Nat.choose n i : ℝ) = (Nat.choose (n - 1) i : ℝ) + (Nat.choose (n - 1) (i - 1) : ℝ) := by
    have h : Nat.choose n i = Nat.choose (n - 1) i + Nat.choose (n - 1) (i - 1) := by
      have h := Nat.choose_succ_succ (n - 1) (i - 1)
      simp only [Nat.succ_eq_add_one, Nat.sub_one_add_one_eq_of_pos hn,
                 Nat.sub_one_add_one_eq_of_pos hi] at h
      linarith
    push_cast [h]; ring
  rcases Nat.lt_or_eq_of_le hin with hlt | heq
  · -- Case i < n
    have h_xi : x ^ i = x ^ (i - 1) * x := by
      conv_lhs => rw [(Nat.succ_pred_eq_of_pos hi).symm, pow_succ]
      simp [Nat.pred_eq_sub_one]
    have h_1mx_lhs : (1 - x) ^ (n - i) = (1 - x) ^ (n - 1 - i) * (1 - x) := by
      have : n - i = (n - 1 - i) + 1 := by omega
      conv_lhs => rw [this, pow_succ]
    have h_1mx_rhs : (1 - x) ^ (n - 1 - (i - 1)) = (1 - x) ^ (n - 1 - i) * (1 - x) := by
      have : n - 1 - (i - 1) = (n - 1 - i) + 1 := by omega
      conv_lhs => rw [this, pow_succ]
    rw [h_pascal, h_xi, h_1mx_lhs, h_1mx_rhs]
    ring
  · -- Case i = n
    subst heq
    have hcz : (Nat.choose (i - 1) i : ℝ) = 0 := by
      exact_mod_cast Nat.choose_eq_zero_of_lt (by omega : i - 1 < i)
    rw [h_pascal, hcz, Nat.sub_self]
    simp [Nat.choose_self]
    conv_lhs => rw [(Nat.succ_pred_eq_of_pos hi).symm, pow_succ]
    simp only [Nat.pred_eq_sub_one]; ring

/-- Degree-1 case: B_{0,1}(x) = 1-x. -/
theorem bernstein_linear_0 (x : ℝ) : bernstein 1 0 x = 1 - x := by
  unfold bernstein
  simp

/-- Degree-1 case: B_{1,1}(x) = x. -/
theorem bernstein_linear_1 (x : ℝ) : bernstein 1 1 x = x := by
  unfold bernstein
  simp [Nat.choose_self]

/-- Degree-2 case: B_{0,2}(x) = (1-x)^2. -/
theorem bernstein_quadratic_0 (x : ℝ) : bernstein 2 0 x = (1 - x) ^ 2 := by
  unfold bernstein
  simp

/-- Degree-2 case: B_{1,2}(x) = 2x(1-x). -/
theorem bernstein_quadratic_1 (x : ℝ) : bernstein 2 1 x = 2 * x * (1 - x) := by
  unfold bernstein
  simp [Nat.choose]

/-- Degree-2 case: B_{2,2}(x) = x^2. -/
theorem bernstein_quadratic_2 (x : ℝ) : bernstein 2 2 x = x ^ 2 := by
  unfold bernstein
  simp [Nat.choose_self]

/-- Out-of-range: B_{i,n}(x) = 0 when i > n (since C(n,i) = 0). -/
theorem bernstein_out_of_range (n i : ℕ) (hi : n < i) (x : ℝ) :
    bernstein n i x = 0 := by
  unfold bernstein
  simp [Nat.choose_eq_zero_of_lt hi]

end FVSquad.BernsteinPolynomial
