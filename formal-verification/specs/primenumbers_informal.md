# Informal Specification: PrimeNumbers

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Source

- **File**: `ql/math/primenumbers.hpp`, `ql/math/primenumbers.cpp`
- **Class**: `PrimeNumbers`
- **Author**: Ferdinando Ametrano (adapted from Peter Jäckel, "Monte Carlo Methods in Finance")

## Purpose

`PrimeNumbers` is a lazy prime number generator that provides the n-th prime number
(0-indexed). It is used in QuantLib for quasi-random number generation (e.g., Halton
sequences) where each dimension requires a distinct prime base.

The class maintains a static memoisation vector, pre-seeded with the first 15 primes
(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47). When a prime at an index
beyond the current list is requested, it extends the list by trial division.

## Interface

### `get(absoluteIndex: Size) → BigNatural`

Returns the prime at position `absoluteIndex` (0-indexed: `get(0) = 2`, `get(1) = 3`, etc.).

## Preconditions

- `absoluteIndex` is a non-negative integer (enforced by `Size` being unsigned).
- No explicit upper bound is documented, but practical limits exist due to memory and
  `BigNatural` (typically `unsigned long`) overflow for very large indices.

## Postconditions

1. **Correctness**: `get(n)` returns the (n+1)-th prime number (the n-th in 0-indexed
   sequence: 2, 3, 5, 7, 11, 13, ...).
2. **Monotonicity**: `get(i) < get(j)` whenever `i < j`.
3. **Primality**: `get(n)` is prime for all valid `n`.
4. **Completeness**: The sequence contains every prime — there are no gaps. That is,
   if `p` is prime and `get(i) < p < get(i+1)`, then no such `p` exists.
5. **Determinism**: Repeated calls with the same index return the same value.
6. **Memoisation**: After `get(n)` is called, all primes up to index `n` are stored.

## Invariants

- The internal vector `primeNumbers_` is always sorted in strictly increasing order.
- Every element of `primeNumbers_` is prime.
- `primeNumbers_` contains exactly the first `primeNumbers_.size()` prime numbers (no gaps).
- The vector is never empty after the first call to `get`.

## Algorithm: `nextPrimeNumber()`

Starting from the last known prime `m`:
1. Increment `m` by 2 (skip even numbers; the list starts with 2, 3 so subsequent primes are odd).
2. Compute `n = floor(sqrt(m))`.
3. Trial-divide `m` by each known prime `p` (starting from index 1, i.e., from 3, since
   even numbers are already skipped).
4. If `m % p == 0` for some `p ≤ n`, then `m` is composite — go to step 1.
5. If no `p ≤ n` divides `m`, then `m` is prime — append to the vector and return.

### Correctness argument

Trial division up to `√m` is sufficient because if `m` has a factor `f > √m`, then
`m/f < √m` is also a factor. Using only known primes as trial divisors (rather than all
odd numbers) is correct because every composite number has a prime factor, and the known
primes list is complete up to the last found prime (which is ≥ √m for candidates tested
sequentially from the previous prime).

## Edge Cases

- **Index 0**: Returns 2 (the smallest prime).
- **Index 1**: Returns 3.
- **Large indices**: No overflow protection. For very large indices, `BigNatural` may
  overflow. The `sqrt` cast `std::sqrt(Real(m))` loses precision for `m > 2^53`, which
  could in theory cause `n` to be slightly wrong — though this is unlikely to cause
  incorrect results in practice since the error would be at most 1.
- **Concurrent access**: The static vector is not thread-safe. Concurrent calls to `get`
  could cause data races (this is a known QuantLib limitation, not specific to this class).

## Examples

| Index | Expected prime |
|-------|---------------|
| 0     | 2             |
| 1     | 3             |
| 2     | 5             |
| 3     | 7             |
| 4     | 11            |
| 9     | 29            |
| 14    | 47            |
| 15    | 53            |
| 24    | 97            |
| 99    | 541           |

## Inferred Intent

The class is designed for quasi-Monte Carlo applications where distinct prime bases are
needed. The emphasis is on correctness and simplicity rather than performance for very
large primes. The pre-seeded table of 15 primes covers common use cases (low-dimensional
quasi-random sequences).

## Open Questions

1. **Thread safety**: Should the memoisation be protected by a mutex? This is a general
   QuantLib concern but affects the specification of `get`'s determinism guarantee under
   concurrent access.
2. **Precision of sqrt**: For very large `m`, the cast to `Real` (double) loses precision.
   Is this considered acceptable, or should an integer square root be used?
3. **Starting from index 1**: The trial division loop starts at `i=1` (skipping the prime 2).
   This is correct because even candidates are already skipped, but it relies on the
   invariant that the candidate is always odd after the initial seeding.

## Properties for Formal Verification

The following properties are strong candidates for Lean 4 formalisation:

1. **Primality**: `∀ n, Nat.Prime (get n)` — every returned value is prime.
2. **Monotonicity**: `∀ i j, i < j → get i < get j` — strictly increasing.
3. **Completeness**: The sequence enumerates all primes in order — `get` is a bijection
   between ℕ and the set of primes (ordered by magnitude).
4. **Seed correctness**: The pre-seeded table `[2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]`
   consists of exactly the first 15 primes.
5. **Trial division correctness**: If no prime ≤ √m divides m, then m is prime.
6. **Step-by-2 correctness**: After 2 and 3, incrementing by 2 never skips a prime.

Mathlib provides `Nat.Prime`, `Nat.minFac`, `Nat.factors`, and related infrastructure
that makes these properties highly tractable in Lean 4.
