/-
  Rounding — Lean 4 formal specification for QuantLib's Rounding class.

  Source: ql/math/rounding.hpp, ql/math/rounding.cpp
  Informal spec: formal-verification/specs/rounding_informal.md

  🔬 Lean Squad — automated formal verification.

  ## Model

  We model the rounding operation over ℚ (rationals) to avoid IEEE 754 complications.
  The C++ implementation works on `double`; our Lean model captures the *mathematical*
  semantics of each rounding mode using exact rational arithmetic.

  ## What the model captures
  - All five OMG rounding modes: None, Up, Down, Closest, Floor, Ceiling
  - Precision parameter (number of decimal places)
  - Rounding digit threshold for Closest/Floor/Ceiling modes
  - Sign-dependent behaviour of Floor and Ceiling modes

  ## What the model does NOT capture
  - IEEE 754 floating-point representation and rounding errors
  - The fast_pow10 lookup table and its masking behaviour
  - NaN/Inf handling
  - Out-of-range precision behaviour (undefined in C++)
-/

import Mathlib.Data.Rat.Defs
import Mathlib.Data.Rat.Floor
import Mathlib.Tactic

namespace FVSquad.Rounding

/-- Rounding modes matching QuantLib's Rounding::Type enum. -/
inductive RoundingType where
  | none     -- Return value unmodified
  | up       -- Round away from zero (if any fractional part exists)
  | down     -- Truncate toward zero
  | closest  -- Round based on digit threshold (OMG round-up)
  | floor    -- Positive: like closest; Negative: like down
  | ceiling  -- Positive: like down; Negative: like closest
  deriving DecidableEq, Repr

/-- Rounding configuration: precision, mode, and digit threshold. -/
structure RoundingConfig where
  precision : ℕ           -- number of decimal places to keep
  type : RoundingType      -- rounding mode
  digit : ℕ               -- threshold digit (default 5)
  deriving DecidableEq, Repr

/-- 10 ^ n as a positive rational. -/
noncomputable def pow10 (n : ℕ) : ℚ := (10 : ℚ) ^ n

/-- The fractional part of a rational number (always in [0, 1)). -/
noncomputable def fracPart (q : ℚ) : ℚ := q - ↑(⌊q⌋)

/-- Core rounding operation over ℚ.

Given a value `v`, precision `p`, rounding type, and digit `d`:
1. Compute `mult = 10^p`
2. Compute `lvalue = |v| * mult`
3. Extract `integral = ⌊lvalue⌋` and `modVal = lvalue - integral`
4. Apply mode-specific rounding to get the adjusted integral
5. Return `sign(v) * adjusted / mult`
-/
noncomputable def roundQ (cfg : RoundingConfig) (v : ℚ) : ℚ :=
  match cfg.type with
  | .none => v
  | _ =>
    let mult := pow10 cfg.precision
    let neg := v < 0
    let absv := |v|
    let lvalue := absv * mult
    let integral := ⌊lvalue⌋
    let modVal := lvalue - ↑integral
    let threshold := (cfg.digit : ℚ) / 10
    let adjusted : ℤ := match cfg.type with
      | .down => integral
      | .up => if modVal ≠ 0 then integral + 1 else integral
      | .closest => if modVal ≥ threshold then integral + 1 else integral
      | .floor =>
        if ¬neg then
          if modVal ≥ threshold then integral + 1 else integral
        else
          integral  -- truncate for negative
      | .ceiling =>
        if neg then
          if modVal ≥ threshold then integral + 1 else integral
        else
          integral  -- truncate for positive
      | .none => integral  -- unreachable
    if neg then -(↑adjusted / mult) else ↑adjusted / mult

-- ============================================================
-- Helper lemmas
-- ============================================================

private theorem pow10_pos (n : ℕ) : (0 : ℚ) < pow10 n :=
  pow_pos (by norm_num : (0:ℚ) < 10) n

private theorem pow10_ne_zero (n : ℕ) : pow10 n ≠ 0 :=
  ne_of_gt (pow10_pos n)

-- ============================================================
-- Theorems — proofs for Rounding properties
-- ============================================================

/-- None mode is the identity function. -/
theorem none_identity (v : ℚ) :
    roundQ ⟨p, .none, d⟩ v = v := by
  simp [roundQ]

/-- Rounding zero always returns zero (for modes where digit > 0).

    Note: When digit = 0 and mode ∈ {closest, floor, ceiling}, the comparison
    `0 ≥ 0/10` is true, causing a spurious round-up of zero. This matches the
    C++ implementation's behaviour (digit=0 is documented as non-meaningful).
    We require digit > 0 to match the OMG spec's intended range {1,...,9}. -/
theorem round_zero (cfg : RoundingConfig)
    (hd : cfg.digit > 0 ∨ cfg.type = .up ∨ cfg.type = .down ∨ cfg.type = .none) :
    roundQ cfg 0 = 0 := by
  simp only [roundQ]
  match htype : cfg.type with
  | .none => simp
  | .down => simp [abs_zero, pow10]
  | .up => simp [abs_zero, pow10]
  | .closest =>
    simp only [abs_zero, zero_mul, Int.floor_zero, Int.cast_zero, sub_zero]
    have hd_pos : cfg.digit > 0 := by
      rcases hd with h | h | h | h <;> [exact h; simp [htype] at h; simp [htype] at h; simp [htype] at h]
    have : ¬((0 : ℚ) ≥ (↑cfg.digit : ℚ) / 10) := by
      push_neg; positivity
    simp [this]
  | .floor =>
    simp only [abs_zero, zero_mul, Int.floor_zero, Int.cast_zero, sub_zero]
    have hlt : ¬((0:ℚ) < 0) := lt_irrefl 0
    simp only [hlt, not_false_eq_true, ↓reduceIte]
    have hd_pos : cfg.digit > 0 := by
      rcases hd with h | h | h | h <;> [exact h; simp [htype] at h; simp [htype] at h; simp [htype] at h]
    have : ¬((0 : ℚ) ≥ (↑cfg.digit : ℚ) / 10) := by
      push_neg; positivity
    simp [this]
  | .ceiling =>
    simp only [abs_zero, zero_mul, Int.floor_zero, Int.cast_zero, sub_zero]
    have hlt : ¬((0:ℚ) < 0) := lt_irrefl 0
    simp only [hlt, not_false_eq_true, ↓reduceIte, Int.cast_zero, zero_div]

/-- For non-negative values, Floor mode equals Closest mode. -/
theorem floor_eq_closest_nonneg (v : ℚ) (hv : 0 ≤ v) (p d : ℕ) :
    roundQ ⟨p, .floor, d⟩ v = roundQ ⟨p, .closest, d⟩ v := by
  simp only [roundQ]
  have hneg : ¬(v < 0) := not_lt.mpr hv
  simp [hneg]

/-- For negative values, Floor mode equals Down mode. -/
theorem floor_eq_down_neg (v : ℚ) (hv : v < 0) (p d : ℕ) :
    roundQ ⟨p, .floor, d⟩ v = roundQ ⟨p, .down, d⟩ v := by
  simp only [roundQ]
  simp [hv]

/-- For non-negative values, Ceiling mode equals Down mode. -/
theorem ceiling_eq_down_nonneg (v : ℚ) (hv : 0 ≤ v) (p d : ℕ) :
    roundQ ⟨p, .ceiling, d⟩ v = roundQ ⟨p, .down, d⟩ v := by
  simp only [roundQ]
  have hneg : ¬(v < 0) := not_lt.mpr hv
  simp [hneg]

/-- For negative values, Ceiling mode equals Closest mode. -/
theorem ceiling_eq_closest_neg (v : ℚ) (hv : v < 0) (p d : ℕ) :
    roundQ ⟨p, .ceiling, d⟩ v = roundQ ⟨p, .closest, d⟩ v := by
  simp only [roundQ]
  simp [hv]

/-- Down mode of a non-negative value is non-negative. -/
theorem down_nonneg (v : ℚ) (hv : 0 ≤ v) (p d : ℕ) :
    0 ≤ roundQ ⟨p, .down, d⟩ v := by
  simp only [roundQ]
  have hneg : ¬(v < 0) := not_lt.mpr hv
  simp [hneg]
  apply div_nonneg
  · exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))
  · exact le_of_lt (pow10_pos p)

/-- Down mode never increases magnitude: |round_down(v)| ≤ |v|. -/
theorem down_le_abs (v : ℚ) (p d : ℕ) :
    |roundQ ⟨p, .down, d⟩ v| ≤ |v| := by
  simp only [roundQ]
  by_cases hv : v < 0
  · -- negative case: result = -(⌊|v|*m⌋/m)
    simp only [hv, ↓reduceIte]
    have hfloor_nn : (0 : ℚ) ≤ ↑⌊|v| * pow10 p⌋ := by
      exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))
    rw [abs_neg, abs_of_nonneg (div_nonneg hfloor_nn (le_of_lt (pow10_pos p)))]
    rw [div_le_iff₀ (pow10_pos p)]
    exact_mod_cast Int.floor_le (|v| * pow10 p)
  · -- nonneg case: result = ⌊|v|*m⌋/m
    simp only [hv, ↓reduceIte]
    have hfloor_nn : (0 : ℚ) ≤ ↑⌊|v| * pow10 p⌋ := by
      exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))
    rw [abs_of_nonneg (div_nonneg hfloor_nn (le_of_lt (pow10_pos p)))]
    rw [div_le_iff₀ (pow10_pos p)]
    exact_mod_cast Int.floor_le (|v| * pow10 p)

/-- Up mode never decreases magnitude. -/
theorem up_ge_abs (v : ℚ) (p d : ℕ) :
    |roundQ ⟨p, .up, d⟩ v| ≥ |v| := by
  unfold roundQ
  simp only
  by_cases hv : v < 0
  · simp only [hv, ↓reduceIte]
    by_cases hmod : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≠ 0
    · rw [if_pos hmod, abs_neg, abs_of_nonneg]
      · rw [ge_iff_le, le_div_iff₀ (pow10_pos p)]
        push_cast
        linarith [Int.lt_floor_add_one (|v| * pow10 p)]
      · apply div_nonneg
        · exact_mod_cast show (0 : ℤ) ≤ ⌊|v| * pow10 p⌋ + 1 by
            linarith [Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))]
        · exact le_of_lt (pow10_pos p)
    · rw [not_not] at hmod
      rw [if_neg (not_not.mpr hmod), abs_neg, abs_of_nonneg]
      · have : |v| * pow10 p = ↑⌊|v| * pow10 p⌋ := by linarith
        rw [ge_iff_le, ← this, mul_div_cancel_right₀ _ (pow10_ne_zero p)]
      · apply div_nonneg
        · exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))
        · exact le_of_lt (pow10_pos p)
  · simp only [hv, ↓reduceIte]
    by_cases hmod : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≠ 0
    · rw [if_pos hmod, abs_of_nonneg]
      · rw [ge_iff_le, le_div_iff₀ (pow10_pos p)]
        push_cast
        linarith [Int.lt_floor_add_one (|v| * pow10 p)]
      · apply div_nonneg
        · exact_mod_cast show (0 : ℤ) ≤ ⌊|v| * pow10 p⌋ + 1 by
            linarith [Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))]
        · exact le_of_lt (pow10_pos p)
    · rw [not_not] at hmod
      rw [if_neg (not_not.mpr hmod), abs_of_nonneg]
      · have : |v| * pow10 p = ↑⌊|v| * pow10 p⌋ := by linarith
        rw [ge_iff_le, ← this, mul_div_cancel_right₀ _ (pow10_ne_zero p)]
      · apply div_nonneg
        · exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg v) (le_of_lt (pow10_pos p)))
        · exact le_of_lt (pow10_pos p)

/-- All rounding modes are idempotent: rounding a rounded value yields the same result. -/
theorem idempotent (cfg : RoundingConfig) (v : ℚ) :
    roundQ cfg (roundQ cfg v) = roundQ cfg v := by
  sorry  -- requires showing rounded values have zero fractional part at the given precision

/-- The result of rounding has at most `p` decimal places:
    `roundQ cfg v * 10^p` is an integer. -/
theorem result_precision (cfg : RoundingConfig) (v : ℚ)
    (htype : cfg.type ≠ .none) :
    ∃ n : ℤ, roundQ cfg v * pow10 cfg.precision = ↑n := by
  unfold roundQ
  have hm : pow10 cfg.precision ≠ 0 := pow10_ne_zero _
  match hcfg : cfg.type with
  | .none => exact absurd hcfg htype
  | .down =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, ↓reduceIte]
      exact ⟨-⌊|v| * pow10 cfg.precision⌋, by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
    · simp only [hcfg, hv, ↓reduceIte]
      exact ⟨⌊|v| * pow10 cfg.precision⌋, div_mul_cancel₀ _ hm⟩
  | .up =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, ↓reduceIte]
      by_cases hmod : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≠ 0
      · rw [if_pos hmod]
        exact ⟨-(⌊|v| * pow10 cfg.precision⌋ + 1), by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
      · rw [if_neg hmod]
        exact ⟨-⌊|v| * pow10 cfg.precision⌋, by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
    · simp only [hcfg, hv, ↓reduceIte]
      by_cases hmod : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≠ 0
      · rw [if_pos hmod]
        exact ⟨⌊|v| * pow10 cfg.precision⌋ + 1, by rw [div_mul_cancel₀ _ hm]⟩
      · rw [if_neg hmod]
        exact ⟨⌊|v| * pow10 cfg.precision⌋, div_mul_cancel₀ _ hm⟩
  | .closest =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, ↓reduceIte]
      by_cases hge : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        exact ⟨-(⌊|v| * pow10 cfg.precision⌋ + 1), by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
      · rw [if_neg hge]
        exact ⟨-⌊|v| * pow10 cfg.precision⌋, by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
    · simp only [hcfg, hv, ↓reduceIte]
      by_cases hge : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        exact ⟨⌊|v| * pow10 cfg.precision⌋ + 1, by rw [div_mul_cancel₀ _ hm]⟩
      · rw [if_neg hge]
        exact ⟨⌊|v| * pow10 cfg.precision⌋, div_mul_cancel₀ _ hm⟩
  | .floor =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, not_true_eq_false, ↓reduceIte]
      exact ⟨-⌊|v| * pow10 cfg.precision⌋, by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
    · simp only [hcfg, hv, not_false_eq_true, ↓reduceIte]
      by_cases hge : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        exact ⟨⌊|v| * pow10 cfg.precision⌋ + 1, by push_cast; rw [div_mul_cancel₀ _ hm]⟩
      · rw [if_neg hge]
        exact ⟨⌊|v| * pow10 cfg.precision⌋, div_mul_cancel₀ _ hm⟩
  | .ceiling =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, ↓reduceIte]
      by_cases hge : |v| * pow10 cfg.precision - ↑⌊|v| * pow10 cfg.precision⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        exact ⟨-(⌊|v| * pow10 cfg.precision⌋ + 1), by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
      · rw [if_neg hge]
        exact ⟨-⌊|v| * pow10 cfg.precision⌋, by rw [neg_mul, div_mul_cancel₀ _ hm]; push_cast; ring⟩
    · simp only [hcfg, hv, ↓reduceIte]
      exact ⟨⌊|v| * pow10 cfg.precision⌋, div_mul_cancel₀ _ hm⟩

/-- Rounding modes with threshold-based rounding (closest, floor, ceiling) are idempotent
    only when `digit > 0`. When `digit = 0`, the threshold is `0/10 = 0`, and since
    `modVal ≥ 0` is always true, a precisely representable value gets spuriously
    rounded up. The modes `none`, `up`, and `down` are unconditionally idempotent.

    The `digit > 0` precondition matches the OMG rounding spec's intended range `{1,...,9}`
    and the C++ implementation's practical usage (default digit = 5). -/
theorem idempotent (cfg : RoundingConfig) (v : ℚ)
    (hd : cfg.digit > 0 ∨ cfg.type = .up ∨ cfg.type = .down ∨ cfg.type = .none) :
    roundQ cfg (roundQ cfg v) = roundQ cfg v := by
  match hcfg : cfg.type with
  | .none => unfold roundQ; simp [hcfg]
  | .down | .up | .closest | .floor | .ceiling =>
    have htype : cfg.type ≠ .none := by simp [hcfg]
    set w := roundQ cfg v with hw_def
    obtain ⟨n, hn⟩ := result_precision cfg v htype
    have hm_ne := pow10_ne_zero cfg.precision
    have hm_pos := pow10_pos cfg.precision
    set m := pow10 cfg.precision with hm_eq
    have hw_eq : w = ↑n / m := by
      field_simp [hm_ne] at hn ⊢; linarith
    -- |w| * m is an integer (= |n|), so floor is itself and modVal = 0
    have habs_eq : |w| * m = |(↑n : ℚ)| := by
      rw [hw_eq, abs_div, abs_of_pos hm_pos, div_mul_cancel₀ _ hm_ne]
    have hmod_eq : |w| * m - ↑⌊|w| * m⌋ = 0 := by
      rw [habs_eq, ← Int.cast_abs, Int.floor_intCast]; simp
    have hfloor_cast : (↑⌊|w| * m⌋ : ℚ) / m = |w| := by
      have h0 : (↑⌊|w| * m⌋ : ℚ) = |w| * m := by linarith [hmod_eq]
      rw [h0, mul_div_cancel_right₀ _ hm_ne]
    unfold roundQ
    match hcfg2 : cfg.type with
    | .none => exact absurd hcfg2 htype
    | .down =>
      by_cases hwn : w < 0
      · simp only [hcfg2, hwn, ↓reduceIte]
        rw [hfloor_cast, abs_of_neg hwn, neg_neg]
      · simp only [hcfg2, hwn, ↓reduceIte]
        rw [hfloor_cast, abs_of_nonneg (not_lt.mp hwn)]
    | .up =>
      have hmod_f : ¬(|w| * m - ↑⌊|w| * m⌋ ≠ 0) := by simp [hmod_eq]
      by_cases hwn : w < 0
      · simp only [hcfg2, hwn, ↓reduceIte]; rw [if_neg hmod_f]
        rw [hfloor_cast, abs_of_neg hwn, neg_neg]
      · simp only [hcfg2, hwn, ↓reduceIte]; rw [if_neg hmod_f]
        rw [hfloor_cast, abs_of_nonneg (not_lt.mp hwn)]
    | .closest =>
      have hd_pos : cfg.digit > 0 := by
        rcases hd with h | h | h | h
        · exact h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
      have hmod_ge : ¬(|w| * m - ↑⌊|w| * m⌋ ≥ ↑cfg.digit / 10) := by
        rw [hmod_eq]; push_neg
        exact div_pos (Nat.cast_pos.mpr hd_pos) (by norm_num : (0:ℚ) < 10)
      by_cases hwn : w < 0
      · simp only [hcfg2, hwn, ↓reduceIte]; rw [if_neg hmod_ge]
        rw [hfloor_cast, abs_of_neg hwn, neg_neg]
      · simp only [hcfg2, hwn, ↓reduceIte]; rw [if_neg hmod_ge]
        rw [hfloor_cast, abs_of_nonneg (not_lt.mp hwn)]
    | .floor =>
      have hd_pos : cfg.digit > 0 := by
        rcases hd with h | h | h | h
        · exact h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
      by_cases hwn : w < 0
      · simp only [hcfg2, hwn, not_true_eq_false, ↓reduceIte]
        rw [hfloor_cast, abs_of_neg hwn, neg_neg]
      · simp only [hcfg2, hwn, not_false_eq_true, ↓reduceIte]
        have hmod_ge : ¬(|w| * m - ↑⌊|w| * m⌋ ≥ ↑cfg.digit / 10) := by
          rw [hmod_eq]; push_neg
          exact div_pos (Nat.cast_pos.mpr hd_pos) (by norm_num : (0:ℚ) < 10)
        rw [if_neg hmod_ge, hfloor_cast, abs_of_nonneg (not_lt.mp hwn)]
    | .ceiling =>
      have hd_pos : cfg.digit > 0 := by
        rcases hd with h | h | h | h
        · exact h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
        · simp [hcfg2] at h
      by_cases hwn : w < 0
      · simp only [hcfg2, hwn, ↓reduceIte]
        have hmod_ge : ¬(|w| * m - ↑⌊|w| * m⌋ ≥ ↑cfg.digit / 10) := by
          rw [hmod_eq]; push_neg
          exact div_pos (Nat.cast_pos.mpr hd_pos) (by norm_num : (0:ℚ) < 10)
        rw [if_neg hmod_ge, hfloor_cast, abs_of_neg hwn, neg_neg]
      · simp only [hcfg2, hwn, ↓reduceIte]
        rw [hfloor_cast, abs_of_nonneg (not_lt.mp hwn)]

/-- Counterexample: idempotent fails for closest mode with digit=0.
    With precision=0, mult=1: roundQ({closest,0,0}) 1 computes |1|*1=1, floor=1, modVal=0,
    threshold=0/10=0, 0≥0 is true, so adjusted=2, result=2 ≠ 1. -/
theorem idempotent_counterexample_digit0 :
    ¬∀ v : ℚ, roundQ ⟨0, .closest, 0⟩ (roundQ ⟨0, .closest, 0⟩ v) = roundQ ⟨0, .closest, 0⟩ v := by
  push_neg
  use 0
  -- roundQ ⟨0, .closest, 0⟩ 0 = 1 (since threshold=0/10=0, modVal=0≥0 → adjusted=1)
  -- roundQ ⟨0, .closest, 0⟩ 1 = 2 (same logic on |1|*1=1, floor=1, mod=0≥0 → adjusted=2)
  -- So double-round gives 2, single-round gives 1.
  unfold roundQ pow10
  simp only [show (0 : ℚ) < 0 ↔ False from by norm_num, ite_false,
    show ¬((0 : ℚ) < 0) from by norm_num]
  norm_num [Int.floor_zero, Int.floor_one]

/-- Helper: |⌊q⌋ - q| ≤ 1 for any rational. -/
private theorem floor_sub_le (q : ℚ) : |(↑⌊q⌋ : ℚ) - q| ≤ 1 := by
  rw [abs_le]; exact ⟨by linarith [Int.lt_floor_add_one q], by linarith [Int.floor_le q]⟩

/-- Helper: |(⌊q⌋ + 1) - q| ≤ 1 for any rational. -/
private theorem floor_add_one_sub_le (q : ℚ) : |(↑(⌊q⌋ + 1) : ℚ) - q| ≤ 1 := by
  have hle := Int.floor_le q
  have hlt := Int.lt_floor_add_one q
  rw [abs_le]; simp only [Int.cast_add, Int.cast_one]
  exact ⟨by linarith, by linarith⟩

/-- Rounding is bounded: the result is within one ULP of the original value. -/
theorem round_bounded (cfg : RoundingConfig) (v : ℚ)
    (htype : cfg.type ≠ .none) :
    |roundQ cfg v - v| ≤ 1 / pow10 cfg.precision := by
  have hm_pos := pow10_pos cfg.precision
  have hm_ne := pow10_ne_zero cfg.precision
  set m := pow10 cfg.precision with hm_def
  have habs_m : |m| = m := abs_of_pos hm_pos
  -- Key helper: |↑adj / m - |v|| ≤ 1/m given adj ∈ {⌊|v|*m⌋, ⌊|v|*m⌋+1}
  have key : ∀ adj : ℤ, (adj = ⌊|v| * m⌋ ∨ adj = ⌊|v| * m⌋ + 1) →
      |(↑adj : ℚ) / m - (|v|)| ≤ 1 / m := by
    intro adj hadj
    rw [le_div_iff₀ hm_pos]
    calc |(↑adj / m - (|v|))| * m
        = |(↑adj / m - (|v|)) * m| := by rw [abs_mul, habs_m]
      _ = |↑adj - |v| * m| := by congr 1; field_simp
      _ ≤ 1 := by
          rcases hadj with h | h <;> subst h
          · exact floor_sub_le _
          · exact floor_add_one_sub_le _
  -- For each mode × sign, reduce to `key`
  unfold roundQ
  match hcfg : cfg.type with
  | .none => exact absurd hcfg htype
  | .down =>
    by_cases hv : v < 0
    · simp only [hcfg, hv, ↓reduceIte]
      have : -(↑⌊|v| * m⌋ / m) - v = |v| - ↑⌊|v| * m⌋ / m := by rw [abs_of_neg hv]; ring
      rw [this, abs_sub_comm]; exact key _ (Or.inl rfl)
    · simp only [hcfg, hv, ↓reduceIte]
      have : ↑⌊|v| * m⌋ / m - v = ↑⌊|v| * m⌋ / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
      rw [this]; exact key _ (Or.inl rfl)
  | .up =>
    by_cases hv : v < 0 <;> simp only [hcfg, hv, ↓reduceIte]
    · by_cases hmod : |v| * m - ↑⌊|v| * m⌋ ≠ 0
      · rw [if_pos hmod]
        have : -(↑(⌊|v| * m⌋ + 1) / m) - v = |v| - ↑(⌊|v| * m⌋ + 1) / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inr rfl)
      · rw [if_neg hmod]
        have : -(↑⌊|v| * m⌋ / m) - v = |v| - ↑⌊|v| * m⌋ / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inl rfl)
    · by_cases hmod : |v| * m - ↑⌊|v| * m⌋ ≠ 0
      · rw [if_pos hmod]
        have : ↑(⌊|v| * m⌋ + 1) / m - v = ↑(⌊|v| * m⌋ + 1) / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inr rfl)
      · rw [if_neg hmod]
        have : ↑⌊|v| * m⌋ / m - v = ↑⌊|v| * m⌋ / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inl rfl)
  | .closest =>
    by_cases hv : v < 0 <;> simp only [hcfg, hv, ↓reduceIte]
    · by_cases hge : |v| * m - ↑⌊|v| * m⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        have : -(↑(⌊|v| * m⌋ + 1) / m) - v = |v| - ↑(⌊|v| * m⌋ + 1) / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inr rfl)
      · rw [if_neg hge]
        have : -(↑⌊|v| * m⌋ / m) - v = |v| - ↑⌊|v| * m⌋ / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inl rfl)
    · by_cases hge : |v| * m - ↑⌊|v| * m⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        have : ↑(⌊|v| * m⌋ + 1) / m - v = ↑(⌊|v| * m⌋ + 1) / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inr rfl)
      · rw [if_neg hge]
        have : ↑⌊|v| * m⌋ / m - v = ↑⌊|v| * m⌋ / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inl rfl)
  | .floor =>
    by_cases hv : v < 0 <;> simp only [hcfg, hv, not_true_eq_false, not_false_eq_true, ↓reduceIte]
    · have : -(↑⌊|v| * m⌋ / m) - v = |v| - ↑⌊|v| * m⌋ / m := by rw [abs_of_neg hv]; ring
      rw [this, abs_sub_comm]; exact key _ (Or.inl rfl)
    · by_cases hge : |v| * m - ↑⌊|v| * m⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        have : ↑(⌊|v| * m⌋ + 1) / m - v = ↑(⌊|v| * m⌋ + 1) / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inr rfl)
      · rw [if_neg hge]
        have : ↑⌊|v| * m⌋ / m - v = ↑⌊|v| * m⌋ / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
        rw [this]; exact key _ (Or.inl rfl)
  | .ceiling =>
    by_cases hv : v < 0 <;> simp only [hcfg, hv, ↓reduceIte]
    · by_cases hge : |v| * m - ↑⌊|v| * m⌋ ≥ ↑cfg.digit / 10
      · rw [if_pos hge]
        have : -(↑(⌊|v| * m⌋ + 1) / m) - v = |v| - ↑(⌊|v| * m⌋ + 1) / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inr rfl)
      · rw [if_neg hge]
        have : -(↑⌊|v| * m⌋ / m) - v = |v| - ↑⌊|v| * m⌋ / m := by rw [abs_of_neg hv]; ring
        rw [this, abs_sub_comm]; exact key _ (Or.inl rfl)
    · have : ↑⌊|v| * m⌋ / m - v = ↑⌊|v| * m⌋ / m - |v| := by rw [abs_of_nonneg (not_lt.mp hv)]
      rw [this]; exact key _ (Or.inl rfl)

/-- When digit = 10, Closest mode is equivalent to Down mode.
    Because threshold = 10/10 = 1, and the fractional part is always < 1,
    the threshold is never reached. -/
theorem closest_digit10_eq_down (v : ℚ) (p : ℕ) :
    roundQ ⟨p, .closest, 10⟩ v = roundQ ⟨p, .down, 10⟩ v := by
  simp only [roundQ, RoundingConfig.mk]
  -- threshold = 10/10 = 1, modVal = lvalue - ⌊lvalue⌋ ∈ [0,1), so modVal < 1 = threshold
  -- meaning the closest branch never rounds up, matching down.
  have key : ∀ q : ℚ, ¬(q - ↑⌊q⌋ ≥ (↑(10:ℕ) : ℚ) / 10) := by
    intro q
    have h10 : (↑(10:ℕ) : ℚ) / 10 = 1 := by norm_num
    rw [h10]; push_neg; exact Int.fract_lt_one q
  by_cases hv : v < 0
  · simp only [hv, ↓reduceIte]; rw [if_neg (key _)]
  · simp only [hv, ↓reduceIte]; rw [if_neg (key _)]

/-- When digit = 0, Closest mode is equivalent to Up mode for non-exact values. -/
theorem closest_digit0_eq_up (v : ℚ) (p : ℕ)
    (hfrac : fracPart (|v| * pow10 p) ≠ 0) :
    roundQ ⟨p, .closest, 0⟩ v = roundQ ⟨p, .up, 0⟩ v := by
  simp only [roundQ, RoundingConfig.mk]
  simp only [Nat.cast_zero, zero_div]
  have hmod : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≥ 0 := by
    have := Int.floor_le (|v| * pow10 p)
    linarith
  have hmod_ne : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≠ 0 := by
    rwa [fracPart, ne_eq] at hfrac
  have hge : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≥ 0 := hmod
  have hne : |v| * pow10 p - ↑⌊|v| * pow10 p⌋ ≠ 0 := hmod_ne
  by_cases hv : v < 0
  · simp only [hv, ↓reduceIte]; rw [if_pos hge, if_pos hne]
  · simp only [hv, ↓reduceIte]; rw [if_pos hge, if_pos hne]

/-- Down rounding is monotone: if a ≤ b then round_down(a) ≤ round_down(b). -/
theorem down_monotone (a b : ℚ) (hab : a ≤ b) (p d : ℕ) :
    roundQ ⟨p, .down, d⟩ a ≤ roundQ ⟨p, .down, d⟩ b := by
  simp only [roundQ]
  by_cases ha : a < 0
  · by_cases hb : b < 0
    · -- both negative: result = -(⌊|v|*m⌋/m), |a| ≥ |b| so ⌊|a|*m⌋ ≥ ⌊|b|*m⌋
      simp only [ha, hb, ↓reduceIte]
      rw [neg_le_neg_iff]
      apply div_le_div_of_nonneg_right _ (pow10_pos p).le
      have hab' : |b| ≤ |a| := by
        rw [abs_of_neg ha, abs_of_neg hb, neg_le_neg_iff]; exact hab
      exact_mod_cast Int.floor_le_floor (mul_le_mul_of_nonneg_right hab' (le_of_lt (pow10_pos p)))
    · -- a < 0 ≤ b: result_a = -(⌊|a|*m⌋/m) ≤ 0 ≤ ⌊|b|*m⌋/m = result_b
      simp only [ha, hb, ↓reduceIte]
      apply le_trans (neg_nonpos_of_nonneg _) (div_nonneg _ (le_of_lt (pow10_pos p)))
      · apply div_nonneg
        · exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg a) (le_of_lt (pow10_pos p)))
        · exact le_of_lt (pow10_pos p)
      · exact_mod_cast Int.floor_nonneg.mpr (mul_nonneg (abs_nonneg b) (le_of_lt (pow10_pos p)))
  · by_cases hb : b < 0
    · -- impossible: a ≥ 0 > b contradicts a ≤ b
      exact absurd (lt_of_le_of_lt hab hb) (not_lt.mpr (not_lt.mp ha))
    · -- both nonneg: result = ⌊|v|*m⌋/m, |a| ≤ |b|
      simp only [ha, hb, ↓reduceIte]
      apply div_le_div_of_nonneg_right _ (pow10_pos p).le
      have hab' : |a| ≤ |b| := by
        rw [abs_of_nonneg (not_lt.mp ha), abs_of_nonneg (not_lt.mp hb)]; exact hab
      exact_mod_cast Int.floor_le_floor (mul_le_mul_of_nonneg_right hab' (le_of_lt (pow10_pos p)))

end FVSquad.Rounding
