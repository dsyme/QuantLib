# Proof Utility Critique

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-05-10 09:51 UTC
- **Commit**: `cb5b81e42` (Run 59)

---

## Overall Assessment

The formal verification effort has produced **245 theorems** across **17 Lean files** covering day counting (Actual360, Actual365Fixed, Thirty360), interest rate compounding (InterestRate), interpolation (LinearInterpolation), probability distributions (NormalDistribution), combinatorics (Factorial), root-finding (Bisection, NewtonSafe), floating-point comparison (FloatingPointClose), option pricing (BlackFormula, PlainVanillaPayoff), linear algebra (Matrix), polynomial algebra (Quadratic), rounding (Rounding), Bernstein polynomials, and cross-target composition (Composition). Approximately **236 theorems are fully proved**; **9 remain `sorry`-guarded** (3 InterestRate Float stdlib, 1 NormalDistribution HasDerivAt, 5 Rounding floor arithmetic). The BlackFormula target axiomatises Φ (1 `sorry` as a definition, not a theorem). This run proved 3 new Rounding theorems (`down_le_abs`, `closest_digit10_eq_down`, `closest_digit0_eq_up`) and fixed broken Mathlib imports.

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
| `down_le_abs` | Rounding.lean | Mid | High | Down mode never increases magnitude ✅ (newly proved) |
| `closest_digit10_eq_down` | Rounding.lean | Mid | Medium | digit=10 ⟹ threshold=1 ⟹ no rounding up ✅ (newly proved) |
| `closest_digit0_eq_up` | Rounding.lean | Mid | Medium | digit=0 ⟹ threshold=0 ⟹ always rounds up ✅ (newly proved) |
| `composition_compoundFactor_pos` | Composition.lean | High | High | Cross-target: compound factor always positive |

*Full inventory: 245 theorems across 17 Lean files. See individual `.lean` files for complete listings.*

---

## Gaps and Recommendations

### High Priority

1. **Rounding: 5 remaining sorry** — `up_ge_abs`, `idempotent`, `result_precision`, `round_bounded`, `down_monotone` all require floor arithmetic (⌊q⌋/m ≤ q/m, fractional part after rounding is zero, etc.). These are mathematically straightforward but need careful Lean/Mathlib floor lemma chaining. **Next step: prove `result_precision` (most tractable) and `down_monotone` (most valuable).**

2. **InterestRate: Float-based continuous compounding** — 3 sorry (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) blocked on `Float.exp_pos`, `Float.log ∘ Float.exp = id`. **Status: blocked on stdlib, acceptable.**

3. **NormalDistribution: `cdf_deriv_eq_pdf`** — Blocked on `HasDerivAt` for erf composition. **Status: blocked on Mathlib analysis API.**

4. **Cross-target composition depth** — The Composition.lean file has 27 theorems but these could be expanded to cover more realistic financial workflows (e.g., full NPV calculation chain, multi-leg instrument pricing).

### Medium Priority

5. **New target: PrimeNumbers** — Informal spec exists (phase 2). Next step: Task 3 (formal spec). The sieve-of-Eratosthenes implementation has clear correctness criteria.

6. **Correspondence tests for newer targets** — Rounding, Composition, and BernsteinPolynomial lack runnable correspondence tests. Quadratic has 63 tests (added Run 55).

7. **New target: Schedule generation** — `ql/time/schedule.hpp` is complex, bug-prone, and has clear correctness criteria.

### Lower Priority

8. **Factorial: connection to Mathlib `Nat.factorial`** — Proving equivalence would bridge to Mathlib's factorial lemma library.

---

## Concerns

1. **Float theorems remain unprovable**: 3 sorry in InterestRate over `Float`. Clearly documented as aspirational. No risk.

2. **No vacuity concerns**: All ~236 proved theorems operate over exact types (`ℚ`, `ℤ`, `ℕ`, `ℝ`) with documented correspondence to C++ formulas. Model approximations are clearly stated.

3. **BlackFormula axiomatises Φ**: 13 theorems hold *relative to* the Φ axiom. The proofs verify formula structure and put-call parity but not CDF implementation. Acceptable.

4. **Rounding model uses ℚ, not IEEE 754**: The 15 Rounding theorems verify the mathematical semantics. 4 known divergences from C++ (Q vs double, fast_pow10 masking, modf semantics, negative zero) are documented in CORRESPONDENCE.md.

5. **Correspondence test coverage**: 10 of 17 targets have runnable tests. The remaining 7 (FloatingPointClose, PlainVanillaPayoff, Matrix, NewtonSafe, BernsteinPolynomial, Rounding, Composition) would benefit from executable validation.

---

## Positive Findings

- **245 theorems with zero implementation bugs found**: all specified mathematical properties of QuantLib's core hold. Strong positive signal for the mathematical foundations.

- **Rounding proofs advancing** (this run): `down_le_abs` proves truncation never increases magnitude using `Int.floor_le`. `closest_digit10_eq_down` and `closest_digit0_eq_up` verify the boundary behaviour of the digit threshold parameter — `Int.fract_lt_one` is the key lemma.

- **Finding from prior run**: `round_zero` theorem was originally stated without a `digit > 0` precondition. When `digit = 0` and mode ∈ {closest, floor, ceiling}, `0 ≥ 0/10` is true, causing spurious round-up of zero. This matches C++ behaviour — the OMG spec documents `digit = 0` as non-meaningful. Fixed by adding precondition.

- **Put-call parity** (`blackPrice_call_put_parity`): formally verifies the fundamental Black-Scholes identity.

- **Broad coverage**: 17 targets across day counting, interest rates, interpolation, distributions, combinatorics, root-finding, floating-point comparison, option pricing, linear algebra, polynomial algebra, rounding, and cross-target composition.
