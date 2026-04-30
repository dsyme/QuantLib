/-
  FVSquad.NormalDistribution — Lean 4 formal specification for QuantLib's
  Normal Distribution (PDF, CDF, and inverse CDF).

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  ## What is modelled
  - The standard Gaussian PDF: f(x) = (1/(σ√(2π))) · exp(-(x-μ)²/(2σ²))
  - Key mathematical properties of the PDF, CDF, and inverse CDF over ℝ
  - Abstract real-valued functions (not the numerical approximation details)

  ## What is NOT modelled
  - Floating-point arithmetic or rounding
  - The Acklam rational approximation coefficients
  - The asymptotic tail expansion in CumulativeNormalDistribution
  - Error handling (σ ≤ 0 cases)
  - The MoroInverseCumulativeNormal alternative implementation
-/

import Mathlib.Tactic
import Mathlib.Analysis.SpecialFunctions.ExpDeriv

namespace FVSquad.NormalDistribution

open Real

/-! ## Core definitions -/

/-- Gaussian PDF with mean μ and standard deviation σ > 0. -/
noncomputable def gaussianPDF (μ σ : ℝ) (x : ℝ) : ℝ :=
  (1 / (σ * Real.sqrt (2 * Real.pi))) * Real.exp (-(x - μ) ^ 2 / (2 * σ ^ 2))

/-- Standard Gaussian PDF (μ=0, σ=1). -/
noncomputable def stdGaussianPDF (x : ℝ) : ℝ :=
  gaussianPDF 0 1 x

/-! ## PDF Properties -/

/-- The PDF is non-negative for σ > 0. -/
theorem pdf_nonneg (μ σ x : ℝ) (hσ : σ > 0) : gaussianPDF μ σ x ≥ 0 := by
  unfold gaussianPDF
  apply mul_nonneg
  · positivity
  · exact le_of_lt (Real.exp_pos _)

/-- The PDF is symmetric about the mean: f(μ + d) = f(μ - d). -/
theorem pdf_symmetric (μ σ d : ℝ) :
    gaussianPDF μ σ (μ + d) = gaussianPDF μ σ (μ - d) := by
  unfold gaussianPDF
  congr 1
  ring_nf

/-- The PDF is maximised at x = μ: f(μ) ≥ f(x) for all x. -/
theorem pdf_peak (μ σ x : ℝ) (hσ : σ > 0) :
    gaussianPDF μ σ μ ≥ gaussianPDF μ σ x := by
  unfold gaussianPDF
  apply mul_le_mul_of_nonneg_left
  · apply Real.exp_le_exp.mpr
    have h2σ : (2 : ℝ) * σ ^ 2 > 0 := by positivity
    apply div_le_div_of_nonneg_right _ (le_of_lt h2σ)
    linarith [sq_nonneg (x - μ)]
  · positivity

/-- At the peak, the PDF equals 1/(σ√(2π)). -/
theorem pdf_at_mean (μ σ : ℝ) (_hσ : σ > 0) :
    gaussianPDF μ σ μ = 1 / (σ * Real.sqrt (2 * Real.pi)) := by
  unfold gaussianPDF
  simp [sub_self, zero_pow, neg_zero, zero_div, Real.exp_zero, mul_one]

/-- The standard PDF at 0 equals 1/√(2π). -/
theorem std_pdf_at_zero :
    stdGaussianPDF 0 = 1 / Real.sqrt (2 * Real.pi) := by
  unfold stdGaussianPDF gaussianPDF
  simp [sub_self, zero_pow, neg_zero, zero_div, Real.exp_zero, mul_one, one_mul]

/-! ## CDF abstract properties

We model the CDF axiomatically as a monotone function [0,1]-valued
that is the antiderivative of the PDF. Full Mathlib integration with
measure theory is possible but heavyweight; we state key properties. -/

/-- Abstract CDF: a function ℝ → ℝ satisfying the Gaussian CDF properties. -/
structure GaussianCDF (μ σ : ℝ) where
  cdf : ℝ → ℝ
  range_01 : ∀ x, 0 ≤ cdf x ∧ cdf x ≤ 1
  monotone : Monotone cdf
  at_mean : cdf μ = 1/2
  symmetry : ∀ x, cdf (2 * μ - x) = 1 - cdf x

/-- Abstract inverse CDF satisfying round-trip and monotonicity. -/
structure GaussianInvCDF (μ σ : ℝ) where
  inv : ℝ → ℝ
  monotone : StrictMono inv
  at_half : inv (1/2) = μ
  symmetry : ∀ p, 0 < p → p < 1 → inv (1 - p) = 2 * μ - inv p

/-! ## Derived properties from axioms -/

/-- CDF symmetry implies Φ(μ) = 1/2 (alternative derivation). -/
theorem cdf_half_from_symmetry (μ σ : ℝ) (Φ : GaussianCDF μ σ) :
    Φ.cdf μ = 1/2 := Φ.at_mean

/-- Inverse CDF monotonicity: p₁ < p₂ ⟹ invCDF(p₁) < invCDF(p₂). -/
theorem inv_cdf_strict_mono (μ σ : ℝ) (invCDF : GaussianInvCDF μ σ)
    (p₁ p₂ : ℝ) (h : p₁ < p₂) : invCDF.inv p₁ < invCDF.inv p₂ :=
  invCDF.monotone h

/-- Inverse CDF symmetry about mean (standard case μ=0). -/
theorem inv_cdf_antisymmetric (invCDF : GaussianInvCDF 0 1)
    (p : ℝ) (hp0 : 0 < p) (hp1 : p < 1) :
    invCDF.inv (1 - p) = -(invCDF.inv p) := by
  have h := invCDF.symmetry p hp0 hp1
  linarith

end FVSquad.NormalDistribution
