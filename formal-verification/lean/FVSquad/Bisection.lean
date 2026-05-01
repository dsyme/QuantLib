/-
  Formal Verification: Bisection 1-D Solver (QuantLib)
  🔬 Lean Squad — automated formal verification.

  Target: ql/math/solvers1d/bisection.hpp
  Models: Bisection::solveImpl(f, xAccuracy)

  Approximations:
  - Uses exact rational arithmetic (ℚ) rather than IEEE 754 floating-point
  - The `close(fMid, 0.0)` early-exit is modelled as exact zero check (fMid = 0)
  - Ignores evaluationNumber_ tracking — focuses on mathematical convergence
  - Models the loop as a recursive function with fuel (iteration count)
  - The QL_FAIL path maps to Option.none (partial function)
  - Does not model the final redundant f(root_) call before return
-/

import Mathlib.Tactic
import Mathlib.Data.Rat.Lemmas

namespace FVSquad.Bisection

/-! ## Types and Definitions -/

/-- State of the bisection algorithm at each iteration.
    Invariant: f changes sign on [root, root + dx] (after orientation). -/
structure BisectState where
  root : ℚ
  dx   : ℚ
  deriving Repr, DecidableEq

/-- Preconditions for bisection: f has opposite signs at endpoints. -/
structure BisectPrecond (f : ℚ → ℚ) (xMin xMax : ℚ) : Prop where
  bracket : f xMin * f xMax ≤ 0
  ordered : xMin ≤ xMax

/-! ## Implementation Model

  We model `solveImpl` as a pure recursive function with fuel.
  The orientation step ensures f(root) ≤ 0 and f(root + dx) ≥ 0.
-/

/-- Orient the search: returns initial state such that f > 0 lies at root + dx. -/
def orient (f : ℚ → ℚ) (xMin xMax : ℚ) : BisectState :=
  if f xMin < 0 then
    { root := xMin, dx := xMax - xMin }
  else
    { root := xMax, dx := xMin - xMax }

/-- One bisection step: halve dx, evaluate midpoint, update root if fMid ≤ 0. -/
def bisectStep (f : ℚ → ℚ) (s : BisectState) : BisectState :=
  let dx' := s.dx / 2
  let xMid := s.root + dx'
  let fMid := f xMid
  if fMid ≤ 0 then
    { root := xMid, dx := dx' }
  else
    { root := s.root, dx := dx' }

/-- Run bisection for `fuel` iterations. Returns `some root` if |dx| < accuracy,
    or `none` if fuel is exhausted. -/
def bisect (f : ℚ → ℚ) (s : BisectState) (accuracy : ℚ) (fuel : ℕ) : Option ℚ :=
  match fuel with
  | 0 => none
  | n + 1 =>
    let s' := bisectStep f s
    if |s'.dx| < accuracy then some s'.root
    else if f (s'.root + s'.dx) = 0 then some (s'.root + s'.dx)  -- exact zero
    else bisect f s' accuracy n

/-- Full bisection solver: orient then iterate. -/
def solve (f : ℚ → ℚ) (xMin xMax : ℚ) (accuracy : ℚ) (fuel : ℕ) : Option ℚ :=
  let s₀ := orient f xMin xMax
  bisect f s₀ accuracy fuel

/-! ## Key Properties

  We state the main correctness properties as theorems.
  These capture the spec-to-implementation gap: the specification is much
  simpler than the implementation (which deals with orientation, mutation,
  evaluation counting, and floating-point).
-/

/-- P1: After k bisection steps, |dx| = |initial_dx| / 2^k.
    This is the fundamental convergence rate guarantee. -/
theorem dx_halves_each_step (f : ℚ → ℚ) (s : BisectState) :
    (bisectStep f s).dx = s.dx / 2 := by
  simp [bisectStep]
  split <;> rfl

/-- Helper: iterate bisectStep k times. -/
def iterateStep (f : ℚ → ℚ) (s : BisectState) : ℕ → BisectState
  | 0 => s
  | n + 1 => bisectStep f (iterateStep f s n)

/-- P1 (general): After k steps, dx = initial_dx / 2^k. -/
theorem dx_after_k_steps (f : ℚ → ℚ) (s : BisectState) (k : ℕ) :
    (iterateStep f s k).dx = s.dx / (2 ^ k : ℚ) := by
  induction k with
  | zero => simp [iterateStep]
  | succ n ih =>
    simp [iterateStep, dx_halves_each_step]
    rw [ih]
    ring

/-- P2: The midpoint computed at each step lies between root and root + dx.
    (Bracket containment — the midpoint is always interior to the bracket.) -/
theorem midpoint_in_bracket (s : BisectState) (hdx : 0 < s.dx) :
    s.root < s.root + s.dx / 2 ∧ s.root + s.dx / 2 < s.root + s.dx := by
  constructor
  · linarith
  · linarith

/-- P2b: The midpoint is also in bracket for negative dx. -/
theorem midpoint_in_bracket_neg (s : BisectState) (hdx : s.dx < 0) :
    s.root + s.dx < s.root + s.dx / 2 ∧ s.root + s.dx / 2 < s.root := by
  constructor
  · linarith
  · linarith

/-- Key lemma: |dx| after one bisectStep is |s.dx|/2. -/
theorem abs_dx_bisectStep (f : ℚ → ℚ) (s : BisectState) :
    |(bisectStep f s).dx| = |s.dx| / 2 := by
  rw [dx_halves_each_step]
  rw [abs_div, abs_of_pos (by norm_num : (2 : ℚ) > 0)]

/-- Key lemma: |dx| after k steps equals |s.dx| / 2^k. -/
theorem abs_dx_after_k_steps (f : ℚ → ℚ) (s : BisectState) (k : ℕ) :
    |(iterateStep f s k).dx| = |s.dx| / (2 ^ k : ℚ) := by
  induction k with
  | zero => simp [iterateStep]
  | succ n ih =>
    simp only [iterateStep]
    rw [abs_dx_bisectStep]
    rw [ih]
    ring

/-- P3: Termination bound — bisection terminates in at most fuel iterations
    when accuracy > 0, fuel > 0, and |dx₀| / 2^fuel < accuracy.
    (The fuel > 0 condition is necessary since bisect with fuel=0 always returns none.) -/
theorem bisect_terminates (f : ℚ → ℚ) (s : BisectState) (acc : ℚ)
    (hacc : 0 < acc) (hdx : |s.dx| ≠ 0) (fuel : ℕ) (hfuel_pos : 0 < fuel)
    (hfuel : (|s.dx| : ℚ) / 2 ^ fuel < acc) :
    (bisect f s acc fuel).isSome = true := by
  induction fuel generalizing s with
  | zero => omega
  | succ n ih =>
    simp only [bisect]
    set s' := bisectStep f s with hs'_def
    have hdx_step : |s'.dx| = |s.dx| / 2 := abs_dx_bisectStep f s
    by_cases h1 : |s'.dx| < acc
    · simp [h1]
    · simp [h1]
      by_cases h2 : f (s'.root + s'.dx) = 0
      · simp [h2]
      · simp [h2]
        have h_s'_dx_pos : (0 : ℚ) < |s'.dx| := by
          rw [hdx_step]; positivity
        have h_s'_dx_ne : |s'.dx| ≠ 0 := ne_of_gt h_s'_dx_pos
        have hfuel' : |s'.dx| / 2 ^ n < acc := by
          have h := hfuel
          rw [hdx_step]
          convert h using 1
          rw [pow_succ]
          ring
        have hn_pos : 0 < n := by
          by_contra h_n0
          push_neg at h_n0
          have hn0 : n = 0 := Nat.eq_zero_of_le_zero h_n0
          rw [hn0, pow_zero, div_one] at hfuel'
          exact absurd hfuel' h1
        exact ih s' h_s'_dx_ne hn_pos hfuel'

/-- Shifting lemma: iterating k+1 times from s equals iterating k times from bisectStep f s. -/
theorem iterateStep_succ_eq (f : ℚ → ℚ) (s : BisectState) (k : ℕ) :
    iterateStep f s (k + 1) = iterateStep f (bisectStep f s) k := by
  induction k with
  | zero => simp [iterateStep]
  | succ m ih => simp only [iterateStep]; congr 1

/-- P4: If bisect returns some r, then either:
    (a) some iteration reached |dx| < accuracy (interval narrowed), or
    (b) an exact zero of f was found during iteration.
    This captures both termination modes of the algorithm. -/
theorem bisect_accuracy (f : ℚ → ℚ) (s : BisectState) (acc : ℚ) (fuel : ℕ) (r : ℚ)
    (h : bisect f s acc fuel = some r) :
    (∃ k, k ≥ 1 ∧ k ≤ fuel ∧ |(iterateStep f s k).dx| < acc) ∨
    (∃ k, k ≥ 1 ∧ k ≤ fuel ∧ f ((iterateStep f s k).root + (iterateStep f s k).dx) = 0) := by
  induction fuel generalizing s with
  | zero => simp [bisect] at h
  | succ n ih =>
    simp only [bisect] at h
    split_ifs at h with h1 h2
    · -- Returned due to accuracy check: |(bisectStep f s).dx| < acc
      left
      exact ⟨1, by omega, by omega, h1⟩
    · -- Returned due to exact zero
      right
      exact ⟨1, by omega, by omega, h2⟩
    · -- Recursed: bisect f (bisectStep f s) acc n = some r
      have ih_result := ih (bisectStep f s) h
      rcases ih_result with ⟨k, hk1, hk2, hk3⟩ | ⟨k, hk1, hk2, hk3⟩
      · left
        refine ⟨k + 1, by omega, by omega, ?_⟩
        rw [iterateStep_succ_eq]; exact hk3
      · right
        refine ⟨k + 1, by omega, by omega, ?_⟩
        rw [iterateStep_succ_eq]; exact hk3

/-- P5: orient produces a state where dx has the correct magnitude. -/
theorem orient_dx_magnitude (f : ℚ → ℚ) (xMin xMax : ℚ) :
    |(orient f xMin xMax).dx| = |xMax - xMin| := by
  simp [orient]
  split
  · ring_nf
  · simp only [abs_sub_comm]

/-- P6: bisectStep preserves that root lies in the original bracket interval.
    If root ∈ [xMin, xMax] before the step, it remains so after. -/
theorem step_root_in_interval (f : ℚ → ℚ) (s : BisectState) (xMin xMax : ℚ)
    (hroot : xMin ≤ s.root ∧ s.root ≤ xMax)
    (hdx : s.root + s.dx ≥ xMin ∧ s.root + s.dx ≤ xMax) :
    let s' := bisectStep f s
    xMin ≤ s'.root ∧ s'.root ≤ xMax := by
  simp [bisectStep]
  split
  · -- fMid ≤ 0: root becomes xMid = root + dx/2
    constructor <;> linarith [hroot.1, hroot.2, hdx.1, hdx.2]
  · -- fMid > 0: root stays the same
    exact hroot

end FVSquad.Bisection
