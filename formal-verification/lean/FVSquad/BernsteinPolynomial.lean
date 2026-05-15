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
import Mathlib.Algebra.BigOperators.Group.Finset
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
  simp [zero_pow (Nat.not_eq_zero_of_lt hi)]

/-- Boundary: B_{i,n}(1) = 0 for i < n. -/
theorem bernstein_at_one (n i : ℕ) (hi : i < n) :
    bernstein n i 1 = 0 := by
  unfold bernstein
  have h : 0 < n - i := Nat.sub_pos_of_lt hi
  simp [zero_pow (Nat.not_eq_zero_of_lt h)]

/-- Symmetry: B_{i,n}(x) = B_{n-i,n}(1-x). -/
theorem bernstein_symmetry (n i : ℕ) (hin : i ≤ n) (x : ℝ) :
    bernstein n i x = bernstein n (n - i) (1 - x) := by
  unfold bernstein
  rw [Nat.choose_symm hin, Nat.sub_sub_self hin, sub_sub_cancel]
  ring

/-- Non-negativity: B_{i,n}(x) ≥ 0 for x ∈ [0, 1]. -/
theorem bernstein_nonneg (n i : ℕ) (hin : i ≤ n) (x : ℝ)
    (hx0 : 0 ≤ x) (hx1 : x ≤ 1) : 0 ≤ bernstein n i x := by
  unfold bernstein
  apply mul_nonneg
  · apply mul_nonneg
    · exact Nat.cast_nonneg
    · exact pow_nonneg hx0 i
  · exact pow_nonneg (by linarith) (n - i)

/-- Partition of unity: ∑_{i=0}^{n} B_{i,n}(x) = 1.
    Follows from the binomial theorem: (x + (1-x))^n = 1. -/
theorem bernstein_partition_of_unity (n : ℕ) (x : ℝ) :
    ∑ i ∈ range (n + 1), bernstein n i x = 1 := by
  sorry -- requires connecting to Nat.add_pow_le or Commute.add_pow

/-- Recursion (de Casteljau): B_{i,n}(x) = (1-x)·B_{i,n-1}(x) + x·B_{i-1,n-1}(x).
    With appropriate boundary conventions for out-of-range indices. -/
theorem bernstein_recursion (n i : ℕ) (hn : 0 < n) (hi : 0 < i) (hin : i ≤ n)
    (x : ℝ) :
    bernstein n i x = (1 - x) * bernstein (n - 1) i x +
                      x * bernstein (n - 1) (i - 1) x := by
  sorry -- requires careful binomial coefficient identity manipulation

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
  ring

/-- Degree-2 case: B_{2,2}(x) = x^2. -/
theorem bernstein_quadratic_2 (x : ℝ) : bernstein 2 2 x = x ^ 2 := by
  unfold bernstein
  simp [Nat.choose_self, Nat.sub_self]

/-- Out-of-range: B_{i,n}(x) = 0 when i > n (since C(n,i) = 0). -/
theorem bernstein_out_of_range (n i : ℕ) (hi : n < i) (x : ℝ) :
    bernstein n i x = 0 := by
  unfold bernstein
  simp [Nat.choose_eq_zero_of_lt hi]

end FVSquad.BernsteinPolynomial
