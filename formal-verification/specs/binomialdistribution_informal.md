# Informal Specification: Binomial Distribution

🔬 *Lean Squad — automated formal verification.*

## Purpose

This module provides:
1. **`binomialCoefficientLn(n, k)`** — the natural log of the binomial coefficient C(n, k)
2. **`binomialCoefficient(n, k)`** — the binomial coefficient C(n, k) = n! / (k! · (n-k)!)
3. **`BinomialDistribution(p, n)(k)`** — the probability mass function P(X = k) for X ~ Binomial(n, p)
4. **`CumulativeBinomialDistribution(p, n)(k)`** — the CDF P(X ≤ k) for X ~ Binomial(n, p)

These are fundamental combinatorial and probabilistic building blocks used throughout QuantLib's lattice methods and tree-based option pricing.

## Source

- **File**: `ql/math/distributions/binomialdistribution.hpp`
- **Dependencies**: `ql/math/factorial.hpp` (for `Factorial::ln`), `ql/math/beta.hpp` (for `incompleteBetaFunction`)

---

## Preconditions

### `binomialCoefficientLn(n, k)`
- `n ≥ k` (enforced by `QL_REQUIRE`)
- `n, k` are non-negative integers (`BigNatural` = unsigned long)

### `binomialCoefficient(n, k)`
- Same as above

### `BinomialDistribution(p, n)`
- `0 ≤ p ≤ 1` (with special handling for p = 0 and p = 1)
- `n ≥ 0` (non-negative integer)

### `CumulativeBinomialDistribution(p, n)`
- `0 ≤ p ≤ 1`
- `n ≥ 0`

---

## Postconditions

### `binomialCoefficientLn(n, k)`
- Returns `ln(n!) - ln(k!) - ln((n-k)!)` = `ln(C(n, k))`
- Result is non-negative (since C(n,k) ≥ 1 for valid inputs)

### `binomialCoefficient(n, k)`
- Returns `floor(0.5 + exp(binomialCoefficientLn(n, k)))` ≈ C(n, k)
- For exact integer results, the floor-rounding guarantees the correct natural number

### `BinomialDistribution(p, n)(k)`
- If `k > n`: returns 0
- If `p = 1`: returns 1 if `k = n`, else 0
- If `p = 0`: returns 1 if `k = 0`, else 0
- Otherwise: returns `C(n, k) · p^k · (1-p)^(n-k)`
- Result is always in `[0, 1]`

### `CumulativeBinomialDistribution(p, n)(k)`
- If `k ≥ n`: returns 1
- Otherwise: returns `1 - I_p(k+1, n-k)` where `I_p` is the regularized incomplete beta function
- Result is always in `[0, 1]`
- Monotonically non-decreasing in `k`

---

## Invariants

1. **Normalization**: `Σ_{k=0}^{n} BinomialDistribution(p, n)(k) = 1` for any valid `p, n`
2. **CDF at boundary**: `CumulativeBinomialDistribution(p, n)(n) = 1`
3. **CDF monotonicity**: `CumulativeBinomialDistribution(p, n)(k) ≤ CumulativeBinomialDistribution(p, n)(k+1)`
4. **PMF-CDF relationship**: `CumulativeBinomialDistribution(p, n)(k) = Σ_{j=0}^{k} BinomialDistribution(p, n)(j)`
5. **Symmetry**: `BinomialDistribution(p, n)(k) = BinomialDistribution(1-p, n)(n-k)`
6. **Binomial coefficient identity**: `C(n, k) = C(n, n-k)`
7. **Pascal's rule**: `C(n+1, k+1) = C(n, k) + C(n, k+1)`
8. **Row sum**: `Σ_{k=0}^{n} C(n, k) = 2^n`
9. **Degenerate cases**:
   - `BinomialDistribution(0, n)(0) = 1` and `BinomialDistribution(0, n)(k) = 0` for `k > 0`
   - `BinomialDistribution(1, n)(n) = 1` and `BinomialDistribution(1, n)(k) = 0` for `k < n`

---

## Edge Cases

| Input | Expected output | Notes |
|-------|----------------|-------|
| `binomialCoefficient(0, 0)` | 1 | C(0,0) = 1 |
| `binomialCoefficient(n, 0)` | 1 | C(n,0) = 1 for all n |
| `binomialCoefficient(n, n)` | 1 | C(n,n) = 1 |
| `binomialCoefficient(n, 1)` | n | C(n,1) = n |
| `BinomialDistribution(0.5, 0)(0)` | 1 | Only outcome for n=0 |
| `BinomialDistribution(0.5, 1)(0)` | 0.5 | Fair coin, 1 trial |
| `BinomialDistribution(0.5, 1)(1)` | 0.5 | Fair coin, 1 trial |
| `BinomialDistribution(p, n)(k)` where k > n | 0 | Impossible outcome |
| `CumulativeBinomialDistribution(p, n)(k)` where k ≥ n | 1 | Certainty |

---

## Examples

| n | k | p | PMF P(X=k) | CDF P(X≤k) |
|---|---|---|------------|------------|
| 5 | 2 | 0.3 | C(5,2)·0.3²·0.7³ = 10·0.09·0.343 = 0.3087 | 0.8369 |
| 10 | 5 | 0.5 | C(10,5)·0.5¹⁰ = 252/1024 ≈ 0.2461 | 0.6230 |
| 4 | 0 | 0.25 | 0.75⁴ ≈ 0.3164 | 0.3164 |
| 4 | 4 | 0.25 | 0.25⁴ ≈ 0.0039 | 1.0 |

---

## Inferred Intent

1. The log-space computation (`binomialCoefficientLn` using `Factorial::ln`) avoids overflow for large `n` — computing `n!` directly would overflow for n > ~170 with doubles.
2. The `floor(0.5 + exp(...))` in `binomialCoefficient` is a rounding trick to recover the exact integer from the floating-point log-exp computation.
3. The PMF uses log-space arithmetic (`exp(ln(C(n,k)) + k·ln(p) + (n-k)·ln(1-p))`) for numerical stability, equivalent to `C(n,k) · p^k · (1-p)^(n-k)`.
4. The CDF uses the incomplete beta function identity: `P(X ≤ k) = 1 - I_p(k+1, n-k)`, which is numerically stable for all parameter ranges.
5. Special handling of `p = 0` and `p = 1` avoids `log(0) = -∞` issues.

---

## Open Questions

1. **Overflow for large n**: The `BigNatural` (unsigned long) limits `n` to ~4 billion on 64-bit systems, but `Factorial::ln` has a lookup table up to n = 170 and uses Stirling's approximation beyond. What is the practical n limit?
2. **Accuracy of incomplete beta**: The CDF delegates to `incompleteBetaFunction` with default accuracy `1e-16`. Is this sufficient for all (n, k, p) triples used in practice?
3. **PeizerPrattMethod2Inversion**: This function inverts the CDF using a normal approximation. Its accuracy degrades for small n or extreme p — should its domain be documented?

---

## FV Strategy

**Recommended approach**: Model `binomialCoefficient` using Lean's `Nat.choose` (which is exact) and the PMF using exact rationals. Key properties to verify:

1. **Binomial coefficient correctness**: `binomialCoefficient(n, k) = Nat.choose n k`
2. **PMF normalization**: `Σ_{k=0}^{n} pmf(p, n, k) = 1` (use `Finset.sum` over `Finset.range (n+1)`)
3. **PMF non-negativity**: `pmf(p, n, k) ≥ 0` for valid inputs
4. **Symmetry**: `pmf(p, n, k) = pmf(1-p, n, n-k)`
5. **Pascal's rule for coefficients**: `choose (n+1) (k+1) = choose n k + choose n (k+1)`
6. **CDF monotonicity**: sum is non-decreasing

Lean/Mathlib already has `Nat.choose`, `Finset.sum`, and `Nat.choose_symm` — many properties should be directly available or one-line proofs.
