/-
  Matrix — Lean 4 formal specification and proofs
  🔬 Lean Squad — automated formal verification for dsyme/QuantLib

  Formally verifies algebraic properties of QuantLib's Matrix class
  (ql/math/matrix.hpp). Models matrices as Fin m → Fin n → ℚ.

  **Approximations**:
  - Uses ℚ (rationals) instead of Float/Real to enable decidable arithmetic
  - Does not model: memory layout, move semantics, iterator machinery,
    bounds checking, error handling, I/O
  - LU-based inverse/determinant not modelled (Boost dependency)
-/

import Mathlib.Data.Matrix.Basic
import Mathlib.LinearAlgebra.Matrix.Determinant.Basic
import Mathlib.LinearAlgebra.Matrix.NonsingularInverse

open Matrix

namespace FVSquad.MatrixSpec

/-! ## Type Aliases -/

/-- QuantLib Matrix modelled as Mathlib Matrix over ℚ -/
abbrev QMatrix (m n : ℕ) := Matrix (Fin m) (Fin n) ℚ

/-! ## Scalar Operations -/

/-- Scalar multiplication: c * M -/
noncomputable def scalarMul (c : ℚ) (M : QMatrix m n) : QMatrix m n :=
  c • M

/-- Scalar division: M / c -/
noncomputable def scalarDiv (M : QMatrix m n) (c : ℚ) (_hc : c ≠ 0) : QMatrix m n :=
  c⁻¹ • M

/-! ## Transpose -/

/-- Transpose matches Mathlib's Mᵀ -/
noncomputable def transpose' (M : QMatrix m n) : QMatrix n m := Mᵀ

/-! ## Matrix Multiplication -/

/-- Matrix-matrix multiplication -/
noncomputable def matMul (A : QMatrix m k) (B : QMatrix k n) : QMatrix m n :=
  A * B

/-! ## Outer Product -/

/-- Outer product of two vectors: result(i,j) = v1(i) * v2(j) -/
def outerProduct (v1 : Fin m → ℚ) (v2 : Fin n → ℚ) : QMatrix m n :=
  Matrix.of fun i j => v1 i * v2 j

/-! ## Diagonal extraction -/

/-- Diagonal of a square matrix -/
def diagVec (M : QMatrix n n) : Fin n → ℚ := fun i => M i i

/-! ## Algebraic Properties — Addition -/

/-- Addition commutativity -/
theorem add_comm' (A B : QMatrix m n) : A + B = B + A := by
  ext i j; exact add_comm _ _

/-- Addition associativity -/
theorem add_assoc' (A B C : QMatrix m n) : A + B + C = A + (B + C) := by
  ext i j; exact add_assoc _ _ _

/-- Additive identity -/
theorem add_zero' (A : QMatrix m n) : A + 0 = A := by
  simp

/-- Additive inverse -/
theorem add_neg_cancel (A : QMatrix m n) : A + (-A) = 0 := by
  simp

/-! ## Algebraic Properties — Scalar Multiplication -/

/-- Scalar distributes over matrix addition -/
theorem smul_add' (c : ℚ) (A B : QMatrix m n) : c • (A + B) = c • A + c • B := by
  ext i j; simp [mul_add]

/-- Scalar multiplication associativity -/
theorem smul_smul' (a b : ℚ) (M : QMatrix m n) : a • (b • M) = (a * b) • M := by
  ext i j; simp [mul_assoc]

/-- Scalar multiplicative identity -/
theorem one_smul' (M : QMatrix m n) : (1 : ℚ) • M = M := by
  simp

/-! ## Transpose Properties -/

/-- Transpose involution: transpose(transpose(A)) = A -/
theorem transpose_transpose' (A : QMatrix m n) : Aᵀᵀ = A := by
  exact Matrix.transpose_transpose A

/-- Transpose distributes over addition -/
theorem transpose_add' (A B : QMatrix m n) : (A + B)ᵀ = Aᵀ + Bᵀ := by
  exact Matrix.transpose_add A B

/-- Transpose of scalar multiply -/
theorem transpose_smul' (c : ℚ) (A : QMatrix m n) : (c • A)ᵀ = c • Aᵀ := by
  exact Matrix.transpose_smul c A

/-! ## Matrix Multiplication Properties -/

/-- Multiplication associativity -/
theorem mul_assoc' (A : QMatrix m k) (B : QMatrix k p) (C : QMatrix p n) :
    A * B * C = A * (B * C) := by
  exact Matrix.mul_assoc A B C

/-- Left-distributivity: A * (B + C) = A*B + A*C -/
theorem mul_add' (A : QMatrix m k) (B C : QMatrix k n) :
    A * (B + C) = A * B + A * C := by
  exact Matrix.mul_add A B C

/-- Right-distributivity: (A + B) * C = A*C + B*C -/
theorem add_mul' (A B : QMatrix m k) (C : QMatrix k n) :
    (A + B) * C = A * C + B * C := by
  exact Matrix.add_mul A B C

/-- Scalar compatibility with multiplication -/
theorem smul_mul' (c : ℚ) (A : QMatrix m k) (B : QMatrix k n) :
    c • (A * B) = (c • A) * B := by
  simp [Matrix.smul_mul]

/-- Transpose reverses multiplication order -/
theorem transpose_mul' (A : QMatrix m k) (B : QMatrix k n) :
    (A * B)ᵀ = Bᵀ * Aᵀ := by
  exact Matrix.transpose_mul A B

/-! ## Outer Product Properties -/

/-- Outer product has correct entry values -/
theorem outerProduct_entry (v1 : Fin m → ℚ) (v2 : Fin n → ℚ) (i : Fin m) (j : Fin n) :
    outerProduct v1 v2 i j = v1 i * v2 j := by
  simp [outerProduct, Matrix.of_apply]

/-! ## Diagonal Properties -/

/-- Diagonal extracts the correct entries -/
theorem diagVec_entry (M : QMatrix n n) (i : Fin n) :
    diagVec M i = M i i := by
  rfl

/-! ## Negation -/

/-- Double negation -/
theorem neg_neg' (A : QMatrix m n) : -(-A) = A := by
  simp

/-- Negation is scalar multiplication by -1 -/
theorem neg_eq_neg_one_smul (A : QMatrix m n) : -A = (-1 : ℚ) • A := by
  ext i j; simp

/-! ## Zero and Identity -/

/-- Multiplying by zero matrix on the right -/
theorem mul_zero' (A : QMatrix m k) : A * (0 : QMatrix k n) = 0 := by
  exact Matrix.mul_zero A

/-- Multiplying by zero matrix on the left -/
theorem zero_mul' (B : QMatrix k n) : (0 : QMatrix m k) * B = 0 := by
  exact Matrix.zero_mul B

/-- Identity is a right-multiplicative identity -/
theorem mul_one' (A : QMatrix m n) : A * (1 : QMatrix n n) = A := by
  exact Matrix.mul_one A

/-- Identity is a left-multiplicative identity -/
theorem one_mul' (A : QMatrix m n) : (1 : QMatrix m m) * A = A := by
  exact Matrix.one_mul A

end FVSquad.MatrixSpec
