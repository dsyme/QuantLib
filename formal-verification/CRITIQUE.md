# Proof Utility Critique

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-05-16 17:29 UTC
- **Commit**: `ac19fa750` (Run 79)

---

## Overall Assessment

The formal verification effort has produced **290 theorems** across **19 Lean files** covering day counting (Actual360, Actual365Fixed, Thirty360), interest rate compounding (InterestRate), interpolation (LinearInterpolation), probability distributions (NormalDistribution), combinatorics (Factorial), root-finding (Bisection, NewtonSafe), floating-point comparison (FloatingPointClose), option pricing (BlackFormula, PlainVanillaPayoff), linear algebra (Matrix), polynomial algebra (Quadratic, BernsteinPolynomial), rounding (Rounding), prime number generation (PrimeNumbers), cross-target composition (Composition), and numerical convergence acceleration (RichardsonExtrapolation). Approximately **286 theorems are fully proved**; **4 remain `sorry`-guarded** (3 InterestRate Float stdlib, 1 NormalDistribution HasDerivAt). The RichardsonExtrapolation file (run 79) adds 7 fully-proved theorems covering exactness, linearity, order improvement, and well-definedness of the Richardson extrapolation formula for real-valued exponents.

---

## Proved Theorems (Selected Highlights)

| Theorem | File | Level | Bug-catching | Notes |
|---------|------|-------|-------------|-------|
| `dayCount_additive` | Actual360.lean | Mid | High | Composability — catches off-by-one |
| `simple_roundtrip_exact` | InterestRate.lean | High | High | Inverse relationship — catches formula errors |
| `compounded_mul_periods` | InterestRate.lean | High | High | Multiplicative structure — key algebraic law |
| `knot_interpolation` | LinearInterpolation.lean | Mid | High | Interpolant passes through data points |
| `day31_eq_day30` | Thirty360.lean | Mid | High | 30/360 convention — industry confusion source |
| `pdf_symmetric` | NormalDistribution.lean | Mid | Medium | Bell curve symmetry about mean |
| `dx_halves_each_step` | Bisection.lean | Mid | High | Convergence rate — key correctness property |
| `close_symm` | FloatingPointClose.lean | Mid | High | Symmetry of closeness relation |
| `blackPrice_call_put_parity` | BlackFormula.lean | High | High | Put-call parity — fundamental financial identity |
| `mul_assoc` | Matrix.lean | High | High | Matrix multiplication associativity |
| `step_contracts_safe` | NewtonSafe.lean | Mid | High | Newton-safe step stays in interval |
| `eval_rootLarge_eq_zero` | Quadratic.lean | High | High | rootLarge is a root |
| `vieta_sum` | Quadratic.lean | High | High | Vieta's formula: r1+r2 = -b/a |
| `down_le_abs` | Rounding.lean | Mid | High | Down mode never increases magnitude |
| `closest_digit10_eq_down` | Rounding.lean | Mid | Medium | digit=10 ⟹ threshold=1 ⟹ no rounding up |
| `closest_digit0_eq_up` | Rounding.lean | Mid | Medium | digit=0 ⟹ threshold=0 ⟹ always rounds up |
| `idempotent_counterexample_digit0` | Rounding.lean | Mid | High | Counterexample: digit=0 breaks idempotent ✅ (newly proved) |
| `composition_compoundFactor_pos` | Composition.lean | High | High | Cross-target: compound factor always positive |
| `exactness_polynomial_error` | RichardsonExtrapolation.lean | High | High | Exact recovery when error is α·h^n |
| `order_improvement` | RichardsonExtrapolation.lean | High | High | Residual after extrapolation is O(h^(n+1)) |

*Full inventory: 283 theorems across 18 Lean files. See individual `.lean` files for complete listings.*

---

## Gaps and Recommendations

### High Priority

1. **InterestRate: Float-based continuous compounding** — 3 sorry (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) blocked on `Float.exp_pos`, `Float.log ∘ Float.exp = id`. **Status: blocked on stdlib, acceptable.**

2. **NormalDistribution: `cdf_deriv_eq_pdf`** — Blocked on `HasDerivAt` for erf composition. **Status: blocked on Mathlib analysis API.**

3. **Cross-target composition depth** — The Composition.lean file has 28 theorems but could be expanded to cover more realistic financial workflows (e.g., full NPV calculation chain, multi-leg instrument pricing).

4. **Lagrange Interpolation** — Identified as target (run 74). Rich algebraic properties: uniqueness, error bounds, Runge phenomenon characterisation. Would extend the interpolation coverage beyond linear.

5. **Correspondence tests for remaining targets** — Composition, BernsteinPolynomial, and RichardsonExtrapolation lack runnable correspondence tests.

### Medium Priority

6. **New target: Schedule generation** — `ql/time/schedule.hpp` is complex, bug-prone, and has clear correctness criteria.

7. **Factorial: connection to Mathlib `Nat.factorial`** — Proving equivalence would bridge to Mathlib's factorial lemma library.

8. **Richardson Extrapolation correspondence tests** — Now that proofs are complete, executable tests comparing the Lean `extrapolate` formula against C++ `RichardsonExtrapolation::operator()` would validate the model.

---

## Concerns

1. **Float theorems remain unprovable**: 3 sorry in InterestRate over `Float`. Clearly documented as aspirational. No risk.

2. **No vacuity concerns**: All ~277 proved theorems operate over exact types (`ℚ`, `ℤ`, `ℕ`, `ℝ`) with documented correspondence to C++ formulas. Model approximations are clearly stated.

3. **BlackFormula axiomatises Φ**: 13 theorems hold *relative to* the Φ axiom. The proofs verify formula structure and put-call parity but not CDF implementation. Acceptable.

4. **Rounding model uses ℚ, not IEEE 754**: The 15 Rounding theorems verify the mathematical semantics. 4 known divergences from C++ (Q vs double, fast_pow10 masking, modf semantics, negative zero) are documented in CORRESPONDENCE.md.

5. **Correspondence test coverage**: 16 of 19 targets have runnable tests. The remaining 3 (Composition, BernsteinPolynomial, RichardsonExtrapolation) would benefit from executable validation.

---

## Positive Findings

- **290 theorems with zero implementation bugs found**: all specified mathematical properties of QuantLib's core hold. Strong positive signal for the mathematical foundations.

- **RichardsonExtrapolation fully proved** (run 79): 7/7 theorems, 0 sorry. Key results include `exactness_polynomial_error` (extrapolation exactly recovers the limit when error is monomial), `order_improvement` (residual is O(h^(n+1))), and `independence_of_t` (result is invariant under subdivision ratio choice). All proofs use `Real.rpow` (real-valued exponents), requiring careful handling of `Real.div_rpow` and `Real.rpow_add` lemmas.

- **BernsteinPolynomial fully proved** (run 78): 15/15 theorems including `bernstein_partition_of_unity` (via binomial theorem) and `bernstein_recursion` (via Pascal's rule). Previously the hardest remaining sorry targets.

- **Rounding fully proved** (run 64): eliminated the last `sorry` in `idempotent_counterexample_digit0`.

- **Finding from prior run**: `round_zero` theorem was originally stated without a `digit > 0` precondition. When `digit = 0` and mode ∈ {closest, floor, ceiling}, `0 ≥ 0/10` is true, causing spurious round-up of zero. This matches C++ behaviour — the OMG spec documents `digit = 0` as non-meaningful. Fixed by adding precondition.

- **Put-call parity** (`blackPrice_call_put_parity`): formally verifies the fundamental Black-Scholes identity.

- **Broad coverage**: 19 targets across day counting, interest rates, interpolation, distributions, combinatorics, root-finding, floating-point comparison, option pricing, linear algebra, polynomial algebra, Bernstein polynomials, rounding, prime numbers, convergence acceleration, and cross-target composition.
