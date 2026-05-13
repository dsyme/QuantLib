/-
  PrimeNumbers — Formal specification and implementation model
  🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

  Source: ql/math/primenumbers.hpp, ql/math/primenumbers.cpp
  Target: The PrimeNumbers class — a lazy prime number generator that returns
          the n-th prime (0-indexed).

  Model approximations:
  - We model the pure mathematical function `nthPrime : ℕ → ℕ` rather than the
    stateful memoisation-based C++ class.
  - Thread safety and overflow concerns are not modelled.
  - The trial division algorithm is modelled but we prove correctness via
    Mathlib's `Nat.Prime` infrastructure rather than verifying the C++ directly.
-/

import Mathlib.Data.Nat.Prime.Nth
import Mathlib.Data.List.Basic

namespace FVSquad.PrimeNumbers

/-! ## Type definitions -/

/-- The seed table of the first 15 primes, matching the C++ `firstPrimes` array. -/
def seedPrimes : List ℕ :=
  [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]

/-- The n-th prime number (0-indexed): `nthPrime 0 = 2`, `nthPrime 1 = 3`, etc. -/
noncomputable def nthPrime (n : ℕ) : ℕ := Nat.nth Nat.Prime n

/-! ## Key properties -/

/-- Every value returned by `nthPrime` is prime. -/
theorem nthPrime_is_prime (n : ℕ) : Nat.Prime (nthPrime n) := by
  sorry

/-- The sequence is strictly monotone. -/
theorem nthPrime_strictMono : StrictMono nthPrime := by
  sorry

/-- Monotonicity corollary: `i < j → nthPrime i < nthPrime j`. -/
theorem nthPrime_lt_of_lt {i j : ℕ} (h : i < j) : nthPrime i < nthPrime j := by
  sorry

/-- Completeness: every prime appears in the sequence. -/
theorem nthPrime_surjective (p : ℕ) (hp : Nat.Prime p) :
    ∃ n, nthPrime n = p := by
  sorry

/-- The first prime is 2. -/
theorem nthPrime_zero : nthPrime 0 = 2 := by
  sorry

/-- The second prime is 3. -/
theorem nthPrime_one : nthPrime 1 = 3 := by
  sorry

/-! ## Seed table correctness -/

/-- All elements of the seed table are prime. -/
theorem seedPrimes_all_prime : ∀ p ∈ seedPrimes, Nat.Prime p := by
  decide

/-- The seed table is sorted in strictly increasing order. -/
theorem seedPrimes_sorted : List.Pairwise (· < ·) seedPrimes := by
  decide

/-- The seed table has exactly 15 elements. -/
theorem seedPrimes_length : seedPrimes.length = 15 := by
  decide

/-- The seed table matches the first 15 primes. -/
theorem seedPrimes_eq_nthPrimes :
    ∀ i : Fin 15, seedPrimes[i] = nthPrime i := by
  sorry

/-! ## Trial division correctness -/

/-- Trial division theorem: if no prime ≤ √m divides m, then m is prime.
    This justifies the C++ `nextPrimeNumber()` algorithm. -/
theorem trial_division_correct (m : ℕ) (hm : m ≥ 2)
    (h : ∀ p, Nat.Prime p → p * p ≤ m → ¬(p ∣ m)) :
    Nat.Prime m := by
  sorry

/-- After 2, all primes are odd — justifies the step-by-2 optimisation. -/
theorem prime_gt_two_odd (p : ℕ) (hp : Nat.Prime p) (h2 : p > 2) :
    ¬ 2 ∣ p := by
  sorry

/-! ## Specific values (correspondence with C++ implementation) -/

/-- `nthPrime 4 = 11` -/
theorem nthPrime_four : nthPrime 4 = 11 := by
  sorry

/-- `nthPrime 9 = 29` -/
theorem nthPrime_nine : nthPrime 9 = 29 := by
  sorry

/-- `nthPrime 14 = 47` -/
theorem nthPrime_fourteen : nthPrime 14 = 47 := by
  sorry

end FVSquad.PrimeNumbers
