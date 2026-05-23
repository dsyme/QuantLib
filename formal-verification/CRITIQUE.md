# Proof Utility Critique

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-05-23 04:12 UTC
- **Commit**: `da839ed3d` (Run 97)

---

## Overall Assessment

The formal verification effort has produced **~331 theorem/lemma declarations** across **22 Lean files** covering day counting (Actual360, Actual365Fixed, Thirty360), interest rate compounding (InterestRate), interpolation (LinearInterpolation, LagrangeInterpolation), probability distributions (NormalDistribution), combinatorics (Factorial), root-finding (Bisection, NewtonSafe, Brent), floating-point comparison (FloatingPointClose), option pricing (BlackFormula, PlainVanillaPayoff), linear algebra (Matrix), polynomial algebra (Quadratic, BernsteinPolynomial), rounding (Rounding), prime number generation (PrimeNumbers), cross-target composition (Composition), and numerical convergence acceleration (RichardsonExtrapolation). Approximately **324 theorems are fully proved**; **7 remain `sorry`-guarded**: 3 InterestRate (Float stdlib), 3 LagrangeInterpolation (complex list algebra), and 1 NormalDistribution (HasDerivAt erf). Since the last critique (run 79), the project has added Brent's method (14 theorems, all proved), LagrangeInterpolation (6/9 proved), and BinomialDistribution (on branch, 13/15 proved).

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
| `bracket_maintained` | Brent.lean | Mid | High | Brent step preserves bracket invariant |
| `convergence_guaranteed` | Brent.lean | Mid | High | Interval shrinks each step → termination |
| `interp_at_node` | LagrangeInterpolation.lean | Mid | High | p(x_i) = y_i — fundamental interpolation correctness |
| `partition_of_unity` | LagrangeInterpolation.lean | Mid | High | Constant function interpolated exactly |

*Full inventory: ~324 proved theorems across 22 Lean files. See individual `.lean` files for complete listings.*

---

## Gaps and Recommendations

### High Priority

1. **LagrangeInterpolation: 3 sorry** — `bary_eq_classical`, `scaling_invariance`, `exact_on_linear`. These require complex list product/sum algebra (factoring `c^n` out of a `List.prod`, distributing sums). The mathematical argument is clear but encoding in Lean's list API is non-trivial. **Recommendation**: consider reformulating over `Fin n → ℚ` (Finset-indexed sums) rather than `List ℚ` to access `Finset.sum_div` and `Finset.prod_mul_distrib` directly.

2. **InterestRate: Float-based continuous compounding** — 3 sorry (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) blocked on `Float.exp_pos`, `Float.log ∘ Float.exp = id`. **Status: blocked on stdlib, acceptable.**

3. **NormalDistribution: `cdf_deriv_eq_pdf`** — Blocked on `HasDerivAt` for erf composition. **Status: blocked on Mathlib analysis API.**

4. **BinomialDistribution (branch, not yet merged)**: 2 sorry — `pmf_sum_eq_one` (requires binomial theorem for rationals), `cdf_le_one` (follows from pmf sum). These could be proved by connecting to `Mathlib.Probability.ProbabilityMassFunction` or using `Finset.sum_div` with the binomial identity.

5. **Cross-target composition depth** — The Composition.lean file has 28 theorems but could be expanded to cover more realistic financial workflows (e.g., full NPV calculation chain, multi-leg instrument pricing).

6. **Copulas** — Informal spec written (run 94). Rich algebraic properties (Fréchet bounds, boundary conditions, associativity for Archimedean copulas). High-value target for financial risk modelling.

7. **Correspondence tests for remaining targets** — Composition, BernsteinPolynomial, and RichardsonExtrapolation lack runnable correspondence tests.

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

5. **Correspondence test coverage**: 16 of 22 targets have runnable tests. The remaining 6 (Composition, BernsteinPolynomial, RichardsonExtrapolation, Brent, LagrangeInterpolation [has tests], BinomialDistribution) would benefit from or already have executable validation.

---

## Positive Findings

- **~324 theorems with zero implementation bugs found**: all specified mathematical properties of QuantLib's core hold. Strong positive signal for the mathematical foundations.

- **Brent's method fully proved** (run 85): 14/14 theorems covering bracket maintenance, convergence, bisection fallback correctness, and inverse quadratic interpolation accuracy. Notably, `bracket_maintained` proves the key invariant that f(root)*f(xMax) ≤ 0 is preserved across iterations — a property that, if violated, would make the algorithm unsound.

- **LagrangeInterpolation partially proved** (runs 86–90): 6/9 theorems proved including `interp_at_node`, `partition_of_unity`, `linearity`, `single_point`, `exact_on_constants`, and `weight_denom_ne_zero`. The 3 remaining sorry require reformulating list products as finset products. The proved theorems already validate the core correctness of the barycentric implementation.

- **RichardsonExtrapolation fully proved** (run 79): 7/7 theorems, 0 sorry. Key results include `exactness_polynomial_error` and `order_improvement`.

- **BernsteinPolynomial fully proved** (run 78): 15/15 theorems including `bernstein_partition_of_unity` (via binomial theorem) and `bernstein_recursion` (via Pascal's rule).

- **Rounding fully proved** (run 64): eliminated the last `sorry` in `idempotent_counterexample_digit0`.

- **Finding from prior run**: `round_zero` theorem was originally stated without a `digit > 0` precondition. When `digit = 0` and mode ∈ {closest, floor, ceiling}, `0 ≥ 0/10` is true, causing spurious round-up of zero. This matches C++ behaviour — the OMG spec documents `digit = 0` as non-meaningful. Fixed by adding precondition.

- **Put-call parity** (`blackPrice_call_put_parity`): formally verifies the fundamental Black-Scholes identity.

- **Broad coverage**: 22 targets across day counting, interest rates, interpolation, distributions, combinatorics, root-finding (3 algorithms), floating-point comparison, option pricing, linear algebra, polynomial algebra, Bernstein polynomials, rounding, prime numbers, convergence acceleration, and cross-target composition.
