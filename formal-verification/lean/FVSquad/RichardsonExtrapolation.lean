/-
  RichardsonExtrapolation — Formal specification and proofs
  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  Source: ql/math/richardsonextrapolation.hpp, ql/math/richardsonextrapolation.cpp
  Target: The RichardsonExtrapolation class — accelerates convergence of
          numerical approximation sequences by cancelling leading error terms.

  Model approximations:
  - We model the known-order extrapolation formula as a pure function on ℝ.
  - The unknown-order mode (using Brent solver) is specified but not modelled
    computationally — it requires root-finding which is separately verified.
  - Floating-point rounding is not modelled; we work in exact real arithmetic.
  - The Null<Real>() sentinel and error handling are not modelled.
-/

import Mathlib.Analysis.SpecificLimits.Basic
import Mathlib.Topology.Algebra.Order.Field
import Mathlib.Tactic

namespace FVSquad.RichardsonExtrapolation

/-! ## Type definitions -/

/-- Configuration for Richardson extrapolation. -/
structure Config where
  /-- The approximation function: f(h) ≈ f₀ as h → 0 -/
  f : ℝ → ℝ
  /-- Initial step size (must be positive) -/
  delta_h : ℝ
  /-- Order of convergence (must be positive for known-order mode) -/
  n : ℝ
  h_pos : delta_h > 0
  n_pos : n > 0

/-! ## Known-order extrapolation formula -/

/-- The Richardson extrapolation formula for known order of convergence.
    Given f(Δh) and f(Δh/t) with convergence order n:
    result = (t^n · f(Δh/t) - f(Δh)) / (t^n - 1) -/
noncomputable def extrapolate (cfg : Config) (t : ℝ) : ℝ :=
  let tk := t ^ cfg.n
  (tk * cfg.f (cfg.delta_h / t) - cfg.f cfg.delta_h) / (tk - 1)

/-! ## Auxiliary lemmas -/

private lemma rpow_gt_one (t n : ℝ) (ht : t > 1) (hn : n > 0) : t ^ n > 1 :=
  (Real.one_lt_rpow_iff_of_pos (by linarith : (0:ℝ) < t)).mpr (Or.inl ⟨ht, hn⟩)

private lemma denom_ne_zero (t n : ℝ) (ht : t > 1) (hn : n > 0) : t ^ n - 1 ≠ 0 := by
  have := rpow_gt_one t n ht hn; linarith

/-! ## Key properties -/

/-- If f(h) = f₀ + α·h^n exactly (no higher-order terms), then
    Richardson extrapolation recovers f₀ exactly. -/
theorem exactness_polynomial_error (f₀ α : ℝ) (cfg : Config) (t : ℝ)
    (ht : t > 1)
    (hf : ∀ h, cfg.f h = f₀ + α * h ^ cfg.n) :
    extrapolate cfg t = f₀ := by
  simp only [extrapolate, hf]
  have htk : t ^ cfg.n - 1 ≠ 0 := denom_ne_zero t cfg.n ht cfg.n_pos
  have ht_pos : (0:ℝ) < t := by linarith
  rw [Real.div_rpow (le_of_lt cfg.h_pos) (le_of_lt ht_pos)]
  rw [show t ^ cfg.n * (f₀ + α * (cfg.delta_h ^ cfg.n / t ^ cfg.n)) -
      (f₀ + α * cfg.delta_h ^ cfg.n) = f₀ * (t ^ cfg.n - 1) from by
    ring_nf; field_simp; ring]
  field_simp

/-- If f is constant (f(h) = c for all h), Richardson extrapolation returns c. -/
theorem constant_function (c : ℝ) (cfg : Config) (t : ℝ)
    (ht : t > 1)
    (hf : ∀ h, cfg.f h = c) :
    extrapolate cfg t = c := by
  simp only [extrapolate, hf]
  have htk : t ^ cfg.n - 1 ≠ 0 := denom_ne_zero t cfg.n ht cfg.n_pos
  field_simp

/-- Richardson extrapolation is linear: if g = a·f₁ + b·f₂ pointwise,
    then extrapolate(g) = a·extrapolate(f₁) + b·extrapolate(f₂). -/
theorem linearity (cfg₁ cfg₂ : Config) (a b : ℝ) (t : ℝ)
    (ht : t > 1)
    (h_same_h : cfg₁.delta_h = cfg₂.delta_h)
    (h_same_n : cfg₁.n = cfg₂.n)
    (cfg_sum : Config)
    (hf_sum : ∀ h, cfg_sum.f h = a * cfg₁.f h + b * cfg₂.f h)
    (h_sum_h : cfg_sum.delta_h = cfg₁.delta_h)
    (h_sum_n : cfg_sum.n = cfg₁.n) :
    extrapolate cfg_sum t = a * extrapolate cfg₁ t + b * extrapolate cfg₂ t := by
  simp only [extrapolate, hf_sum]
  have htk : t ^ cfg_sum.n - 1 ≠ 0 := denom_ne_zero t cfg_sum.n ht cfg_sum.n_pos
  have htk₁ : t ^ cfg₁.n - 1 ≠ 0 := denom_ne_zero t cfg₁.n ht cfg₁.n_pos
  have htk₂ : t ^ cfg₂.n - 1 ≠ 0 := by rw [← h_same_n]; exact htk₁
  rw [h_sum_h, h_sum_n, h_same_h, h_same_n]
  field_simp
  ring

/-- The extrapolation result is independent of the choice of t when
    the error is exactly α·h^n (no higher-order terms).
    That is, for any t₁, t₂ > 1, extrapolate(t₁) = extrapolate(t₂). -/
theorem independence_of_t (f₀ α : ℝ) (cfg : Config) (t₁ t₂ : ℝ)
    (ht₁ : t₁ > 1) (ht₂ : t₂ > 1)
    (hf : ∀ h, cfg.f h = f₀ + α * h ^ cfg.n) :
    extrapolate cfg t₁ = extrapolate cfg t₂ := by
  rw [exactness_polynomial_error f₀ α cfg t₁ ht₁ hf,
      exactness_polynomial_error f₀ α cfg t₂ ht₂ hf]

/-- When the error term is α·h^n + β·h^(n+1) + ..., the extrapolated
    result has error O(h^(n+1)). We state this as: the residual after
    extrapolation is proportional to h^(n+1), not h^n. -/
theorem order_improvement (f₀ α β : ℝ) (cfg : Config) (t : ℝ)
    (ht : t > 1)
    (hf : ∀ h, cfg.f h = f₀ + α * h ^ cfg.n + β * h ^ (cfg.n + 1)) :
    extrapolate cfg t - f₀ = β * cfg.delta_h ^ (cfg.n + 1) *
      (1 / t - 1) / (t ^ cfg.n - 1) := by
  simp only [extrapolate, hf]
  have htk : t ^ cfg.n - 1 ≠ 0 := denom_ne_zero t cfg.n ht cfg.n_pos
  have ht_pos : (0:ℝ) < t := by linarith
  have ht_ne : (t : ℝ) ≠ 0 := by linarith
  rw [Real.div_rpow (le_of_lt cfg.h_pos) (le_of_lt ht_pos)]
  rw [show cfg.n + 1 = cfg.n + (1:ℝ) from rfl]
  rw [Real.div_rpow (le_of_lt cfg.h_pos) (le_of_lt ht_pos)]
  rw [Real.rpow_add (by linarith : (0:ℝ) < t)]
  rw [Real.rpow_add (by exact cfg.h_pos)]
  simp only [Real.rpow_one]
  field_simp
  ring

/-! ## Precondition properties -/

/-- The denominator t^n - 1 is nonzero when t > 1 and n > 0. -/
theorem denom_nonzero (t n : ℝ) (ht : t > 1) (hn : n > 0) :
    t ^ n - 1 ≠ 0 :=
  denom_ne_zero t n ht hn

/-! ## Specific values (correspondence with C++ implementation) -/

/-- Example: f(h) = 1 + 3h², Δh = 1, t = 2, n = 2 → result = 1.0 -/
theorem example_quadratic_error :
    let cfg : Config := ⟨fun h => 1 + 3 * h ^ (2:ℝ), 1, 2, by norm_num, by norm_num⟩
    extrapolate cfg 2 = 1 := by
  simp only [extrapolate]
  have h2 : (2:ℝ) ^ (2:ℝ) = 4 := by
    have : (2:ℝ) ^ (2:ℝ) = (2:ℝ) ^ (2:ℕ) := by norm_cast
    rw [this]; norm_num
  have h3 : (1:ℝ) ^ (2:ℝ) = 1 := Real.one_rpow 2
  have h4 : ((1:ℝ) / 2) ^ (2:ℝ) = 1 / 4 := by
    have : ((1:ℝ) / 2) ^ (2:ℝ) = ((1:ℝ) / 2) ^ (2:ℕ) := by norm_cast
    rw [this]; norm_num
  rw [h2, show (1:ℝ) / (2:ℝ) = (1:ℝ) / 2 from rfl, h4, h3]
  norm_num

end FVSquad.RichardsonExtrapolation
