/-
  FVSquad.PlainVanillaPayoff — Lean 4 formal specification and proofs for
  QuantLib's PlainVanillaPayoff (plain vanilla option payoff).

  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  ## What is modelled
  - Call payoff: max(S − K, 0)
  - Put payoff: max(K − S, 0)
  - Key algebraic properties: non-negativity, put-call parity, monotonicity,
    out-of-the-money behaviour, at-the-money, convexity, symmetry

  ## What is NOT modelled
  - The C++ class hierarchy (Payoff / TypePayoff / StrikedTypePayoff)
  - Visitor pattern and virtual dispatch
  - Floating-point arithmetic
  - Error handling

  Source: ql/instruments/payoffs.hpp/cpp — PlainVanillaPayoff::operator()
-/

import Mathlib.Tactic

namespace FVSquad.PlainVanillaPayoff

open Real

/-! ## Option Type -/

inductive OptionType where
  | Call : OptionType
  | Put  : OptionType
deriving DecidableEq, Repr

/-! ## Core definitions -/

/-- Plain vanilla payoff: max(S − K, 0) for Call, max(K − S, 0) for Put.
    Models PlainVanillaPayoff::operator()(Real price) in QuantLib. -/
noncomputable def payoff (typ : OptionType) (K S : ℝ) : ℝ :=
  match typ with
  | .Call => max (S - K) 0
  | .Put  => max (K - S) 0

/-! ## Non-negativity -/

/-- Call payoff is non-negative. -/
theorem call_nonneg (K S : ℝ) : payoff .Call K S ≥ 0 := by
  unfold payoff; exact le_max_right _ _

/-- Put payoff is non-negative. -/
theorem put_nonneg (K S : ℝ) : payoff .Put K S ≥ 0 := by
  unfold payoff; exact le_max_right _ _

/-- Both payoff types are non-negative. -/
theorem payoff_nonneg (typ : OptionType) (K S : ℝ) : payoff typ K S ≥ 0 := by
  cases typ <;> unfold payoff <;> exact le_max_right _ _

/-! ## Put-call parity -/

/-- Put-call parity: call(S) − put(S) = S − K. -/
theorem put_call_parity (K S : ℝ) :
    payoff .Call K S - payoff .Put K S = S - K := by
  simp only [payoff]
  by_cases h : S ≤ K
  · rw [max_eq_right (by linarith : S - K ≤ 0), max_eq_left (by linarith : K - S ≥ 0)]
    ring
  · push_neg at h
    rw [max_eq_left (by linarith : S - K ≥ 0), max_eq_right (by linarith : K - S ≤ 0)]
    ring

/-! ## Out-of-the-money behaviour -/

/-- Call is zero when S ≤ K (out of the money). -/
theorem call_otm (K S : ℝ) (h : S ≤ K) : payoff .Call K S = 0 := by
  unfold payoff; exact max_eq_right (by linarith)

/-- Put is zero when S ≥ K (out of the money). -/
theorem put_otm (K S : ℝ) (h : S ≥ K) : payoff .Put K S = 0 := by
  unfold payoff; exact max_eq_right (by linarith)

/-! ## In-the-money behaviour -/

/-- Call equals S − K when S ≥ K (in the money). -/
theorem call_itm (K S : ℝ) (h : S ≥ K) : payoff .Call K S = S - K := by
  unfold payoff; exact max_eq_left (by linarith)

/-- Put equals K − S when S ≤ K (in the money). -/
theorem put_itm (K S : ℝ) (h : S ≤ K) : payoff .Put K S = K - S := by
  unfold payoff; exact max_eq_left (by linarith)

/-! ## At-the-money -/

/-- At the money (S = K), call payoff is zero. -/
theorem call_atm (K : ℝ) : payoff .Call K K = 0 := by
  unfold payoff; simp

/-- At the money (S = K), put payoff is zero. -/
theorem put_atm (K : ℝ) : payoff .Put K K = 0 := by
  unfold payoff; simp

/-! ## Monotonicity -/

/-- Call payoff is non-decreasing in S. -/
theorem call_mono (K S₁ S₂ : ℝ) (h : S₁ ≤ S₂) :
    payoff .Call K S₁ ≤ payoff .Call K S₂ := by
  unfold payoff
  exact max_le_max_right 0 (by linarith)

/-- Put payoff is non-increasing in S. -/
theorem put_antimono (K S₁ S₂ : ℝ) (h : S₁ ≤ S₂) :
    payoff .Put K S₂ ≤ payoff .Put K S₁ := by
  unfold payoff
  exact max_le_max_right 0 (by linarith)

/-! ## Symmetry: swapping S and K swaps call/put -/

/-- Symmetry: call(K, S) = put(S, K). -/
theorem call_put_symmetry (K S : ℝ) :
    payoff .Call K S = payoff .Put S K := by
  simp [payoff]

/-! ## Special edge cases -/

/-- When S = 0, call payoff is 0 (for K ≥ 0). -/
theorem call_zero_price (K : ℝ) (hK : K ≥ 0) : payoff .Call K 0 = 0 :=
  call_otm K 0 (by linarith)

/-- When S = 0, put payoff is K (for K ≥ 0). -/
theorem put_zero_price (K : ℝ) (hK : K ≥ 0) : payoff .Put K 0 = K := by
  have : payoff .Put K 0 = K - 0 := put_itm K 0 (by linarith)
  linarith

/-- When K = 0, call payoff is S (for S ≥ 0). -/
theorem call_zero_strike (S : ℝ) (hS : S ≥ 0) : payoff .Call 0 S = S := by
  have : payoff .Call 0 S = S - 0 := call_itm 0 S (by linarith)
  linarith

/-- When K = 0, put payoff is 0 (for S ≥ 0). -/
theorem put_zero_strike (S : ℝ) (hS : S ≥ 0) : payoff .Put 0 S = 0 :=
  put_otm 0 S (by linarith)

/-! ## Convexity -/

private theorem max_convex_helper (a b t : ℝ) (ht₁ : 0 ≤ t) (ht₂ : t ≤ 1) :
    max (t * a + (1 - t) * b) 0 ≤ t * max a 0 + (1 - t) * max b 0 := by
  have hμ : (0 : ℝ) ≤ 1 - t := by linarith
  apply max_le
  · have ha : a ≤ max a 0 := le_max_left a 0
    have hb : b ≤ max b 0 := le_max_left b 0
    have h1 := mul_le_mul_of_nonneg_left ha ht₁
    have h2 := mul_le_mul_of_nonneg_left hb hμ
    linarith
  · have h1 : (0 : ℝ) ≤ t * max a 0 := mul_nonneg ht₁ (le_max_right a 0)
    have h2 : (0 : ℝ) ≤ (1 - t) * max b 0 := mul_nonneg hμ (le_max_right b 0)
    linarith

/-- Call payoff is convex: payoff(t·S₁ + (1−t)·S₂) ≤ t·payoff(S₁) + (1−t)·payoff(S₂). -/
theorem call_convex (K S₁ S₂ t : ℝ) (ht₁ : 0 ≤ t) (ht₂ : t ≤ 1) :
    payoff .Call K (t * S₁ + (1 - t) * S₂) ≤
    t * payoff .Call K S₁ + (1 - t) * payoff .Call K S₂ := by
  simp only [payoff]
  have hkey : t * S₁ + (1 - t) * S₂ - K = t * (S₁ - K) + (1 - t) * (S₂ - K) := by ring
  rw [hkey]
  exact max_convex_helper (S₁ - K) (S₂ - K) t ht₁ ht₂

/-- Put payoff is convex. -/
theorem put_convex (K S₁ S₂ t : ℝ) (ht₁ : 0 ≤ t) (ht₂ : t ≤ 1) :
    payoff .Put K (t * S₁ + (1 - t) * S₂) ≤
    t * payoff .Put K S₁ + (1 - t) * payoff .Put K S₂ := by
  simp only [payoff]
  have hkey : K - (t * S₁ + (1 - t) * S₂) = t * (K - S₁) + (1 - t) * (K - S₂) := by ring
  rw [hkey]
  exact max_convex_helper (K - S₁) (K - S₂) t ht₁ ht₂

/-! ## Verification -/

#check @call_nonneg
#check @put_call_parity
#check @call_convex

end FVSquad.PlainVanillaPayoff
