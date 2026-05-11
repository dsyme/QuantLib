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
  sorry  -- requires showing (⌊|v| * 10^p⌋ + ε) / 10^p ≥ |v|; needs floor/ceil lemmas

/-- All rounding modes are idempotent: rounding a rounded value yields the same result. -/
theorem idempotent (cfg : RoundingConfig) (v : ℚ) :
    roundQ cfg (roundQ cfg v) = roundQ cfg v := by
  sorry  -- requires showing rounded values have zero fractional part at the given precision

/-- The result of rounding has at most `p` decimal places:
    `roundQ cfg v * 10^p` is an integer. -/
theorem result_precision (cfg : RoundingConfig) (v : ℚ)
    (htype : cfg.type ≠ .none) :
    ∃ n : ℤ, roundQ cfg v * pow10 cfg.precision = ↑n := by
  sorry  -- result is ±⌊...⌋/10^p or ±(⌊...⌋+1)/10^p; needs split_ifs + div_mul_cancel₀

/-- Rounding is bounded: the result is within one ULP of the original value. -/
theorem round_bounded (cfg : RoundingConfig) (v : ℚ)
    (htype : cfg.type ≠ .none) :
    |roundQ cfg v - v| ≤ 1 / pow10 cfg.precision := by
  sorry  -- needs floor arithmetic and case analysis on rounding direction

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
