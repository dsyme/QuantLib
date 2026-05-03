> 🔬 *Lean Squad — automated formal verification for `dsyme/QuantLib`.*

**Status**: 🔄 IN PROGRESS — 140 theorems (136 proved, 4 `sorry`), 12 Lean files, 12 targets, Lean 4 + Mathlib.

## Last Updated
- **Date**: 2026-05-03 04:16 UTC
- **Commit**: `8551bfa66`

---

## Executive Summary

Formal verification of QuantLib's quantitative finance primitives is mature across 11 targets using Lean 4 with Mathlib. **136 of 140 theorems are fully proved** with only 4 `sorry` remaining (3 Float axioms in InterestRate, 1 HasDerivAt in NormalDistribution — both fundamentally blocked by Lean stdlib limitations). Nine targets are fully verified with zero sorry: **Actual360** (8 theorems, ~2,920 correspondence tests), **Actual365Fixed** (8 theorems, 2,295 tests), **LinearInterpolation** (7 theorems, 12 tests), **Thirty360** (11 theorems, 575 tests), **Factorial** (10 theorems, 28 tests), **Bisection** (11 theorems), **FloatingPointClose** (12 theorems), **BlackFormula** (13 theorems, 312 tests), and **NewtonSafe** (13 theorems — bracket preservation, Newton/bisection switching, convergence). **NormalDistribution** has 14 theorems (13 proved, 1 sorry) with 1,082 correspondence tests. **InterestRate** has 30 theorems (27 proved, 3 sorry) across Rat/ℝ/Float models with 1,394 tests. Over **8,600 correspondence test cases** validate model fidelity. Zero bugs found — the implementations match their mathematical specifications. Matrix remains in research phase.

---

## Proof Architecture

The verification is organised into independent target modules, each modelling a specific QuantLib component. Targets span day counting, interest rate algebra, interpolation, probability distributions, combinatorics, and numerical solvers.

```mermaid
graph TD
    A["FVSquad.Basic<br/>(project root)"]
    B["FVSquad.Actual360<br/>8 theorems ✅"]
    B2["FVSquad.Actual365Fixed<br/>8 theorems ✅"]
    C["FVSquad.InterestRate<br/>27 proved + 3 sorry"]
    D["FVSquad.LinearInterpolation<br/>7 theorems ✅"]
    E["FVSquad.Thirty360<br/>11 theorems ✅"]
    F["FVSquad.NormalDistribution<br/>13 proved + 1 sorry"]
    G["FVSquad.Factorial<br/>10 theorems ✅"]
    H["FVSquad.Bisection<br/>11 theorems ✅"]
    A --> B
    A --> B2
    A --> C
    A --> D
    A --> E
    A --> F
    A --> G
    A --> H
    C1["Rat model<br/>16 theorems ✅"]
    C2["Real model (Mathlib)<br/>11 theorems ✅"]
    C3["Float model<br/>3 sorry 🔄"]
    C --> C1
    C --> C2
    C --> C3
```

---

## What Was Verified

### Layer 1 — Day Counting (3 files, 27 theorems)

Models day counting conventions used throughout QuantLib for year-fraction calculations.

```mermaid
graph LR
    F1["Actual360.lean<br/>8 theorems ✅<br/>Additivity, antisymmetry"]
    F2["Actual365Fixed.lean<br/>8 theorems ✅<br/>Additivity, translation invariance"]
    F4["Thirty360.lean<br/>11 theorems ✅<br/>EU convention, adjustment"]
```

**Key results**:
- `dayCount_additive`: `dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)` (both Actual360 and Actual365Fixed)
- `dayCount_antisymm`: reversal symmetry
- `dayCount_includeLastDay_off_by_one`: exact off-by-one characterisation (Actual360)
- `dayCount_translate`: translation invariance `dayCount(d1+k, d2+k) = dayCount(d1, d2)` (Actual365Fixed)
- `dayCount_full_year`: `dayCount(d, d+365) = 365` (Actual365Fixed)
- `adjust_idempotent`: day-31 adjustment is idempotent (Thirty360)
- `antisymmetry`, `full_year`, `full_month`: canonical Thirty360 EU properties

### Layer 2 — Interest Rate Compounding (1 file, 27 proved + 3 sorry)

Models `InterestRate::compoundFactor` and `impliedRate`. Triple-model: exact `Rat`, Mathlib `ℝ`, and `Float`.

```mermaid
graph LR
    F2["InterestRate.lean<br/>27 proved ✅ + 3 sorry 🔄<br/>Round-trip, identities,<br/>monotonicity, exp/log"]
```

**Key results**:
- `simple_roundtrip_exact`: `impliedSimpleQ(compoundSimpleQ(r, t), t) = r`
- `continuousR_roundtrip`: `log(exp(r·t))/t = r` (Mathlib ℝ)
- `continuousR_ge_simple`: continuous ≥ simple compounding
- `continuousR_monotone_rate`, `continuousR_monotone_time`: monotonicity
- `compounded_monotone_periods`: more compounding periods ⇒ higher factor

### Layer 3 — Interpolation (1 file, 7 theorems)

```mermaid
graph LR
    F3["LinearInterpolation.lean<br/>7 theorems ✅<br/>Knot interpolation, derivative,<br/>monotonicity"]
```

**Key results**:
- `second_derivative_zero`: piecewise linearity
- `knot_interpolation`: exact interpolation at knot points
- `monotone_nonneg_slope`, `antitone_nonpos_slope`: monotonicity preservation

### Layer 4 — Probability Distributions (1 file, 13 proved + 1 sorry)

Models `NormalDistribution` and `CumulativeNormalDistribution` via Gaussian PDF and erf-based CDF.

```mermaid
graph LR
    F5["NormalDistribution.lean<br/>13 proved ✅ + 1 sorry 🔄<br/>PDF properties, CDF symmetry,<br/>inverse CDF monotonicity"]
```

**Key results**:
- `pdf_nonneg`, `pdf_symmetric`, `pdf_peak`: PDF fundamental properties
- `cdf_at_mean`: Φ(μ) = 1/2
- `cdf_symmetry`: Φ(2μ−x) + Φ(x) = 1 (via `erf_neg`)
- `inv_cdf_strict_mono`, `inv_cdf_antisymmetric`: inverse CDF properties
- `pdf_deriv_at_mean`, `pdf_deriv_neg_right`, `pdf_deriv_pos_left`: derivative signs

### Layer 5 — Combinatorics (1 file, 10 theorems)

Models `QuantLib::factorial()` from `ql/math/factorial.hpp`.

```mermaid
graph LR
    F6["Factorial.lean<br/>10 theorems ✅<br/>Recursion, growth bounds,<br/>divisibility"]
```

**Key results**:
- `factorial_growth`: `n! ≥ 2^(n-1)` for `n ≥ 1`
- `factorial_sum_ge_mul`: `(m+n)! ≥ m!·n!`
- `factorial_even_div`: `2^n | (2n)!`
- `factorial_strict_mono`, `factorial_pos`: structural properties

### Layer 6 — Numerical Solvers (1 file, 11 theorems)

Models the bisection root-finding algorithm from `ql/math/solvers1d/bisection.hpp`.

```mermaid
graph LR
    F7["Bisection.lean<br/>11 theorems ✅<br/>Convergence, termination,<br/>accuracy guarantee"]
```

**Key results**:
- `dx_halves_each_step`: `|dx_{k+1}| = |dx_k|/2`
- `abs_dx_after_k_steps`: `|dx_k| = |dx_0|/2^k` (inductive)
- `bisect_terminates`: solver always returns when `|dx|/2^fuel < acc`
- `bisect_accuracy`: any result satisfies `|dx| < accuracy` or is an exact root
- `midpoint_in_bracket`, `midpoint_in_bracket_neg`: bracket invariant

---

## File Inventory

| File | Proved | Sorry | Phase | Key result |
|------|--------|-------|-------|------------|
| `Actual360.lean` | 8 | 0 | ✅ Fully proved | Additivity, antisymmetry, non-negativity |
| `Actual365Fixed.lean` | 8 | 0 | ✅ Fully proved | Additivity, translation invariance, full year |
| `InterestRate.lean` | 27 | 3 | 🔄 Partial (Float) | Round-trip, identities, monotonicity, exp/log |
| `LinearInterpolation.lean` | 7 | 0 | ✅ Fully proved | Knot interpolation, derivative, monotonicity |
| `Thirty360.lean` | 11 | 0 | ✅ Fully proved | Same-date, antisymmetry, adjustment, additivity |
| `NormalDistribution.lean` | 13 | 1 | 🔄 Partial (HasDerivAt) | PDF/CDF properties, symmetry, inverse monotonicity |
| `Factorial.lean` | 10 | 0 | ✅ Fully proved | Growth bounds, divisibility, recursion |
| `Bisection.lean` | 11 | 0 | ✅ Fully proved | Convergence, termination, accuracy guarantee |
| `FloatingPointClose.lean` | 12 | 0 | ✅ Fully proved | Reflexivity, symmetry, triangle inequality |
| `BlackFormula.lean` | 13 | 0 | ✅ Fully proved | Put-call parity, non-negativity, boundary limits |
| `NewtonSafe.lean` | 13 | 0 | ✅ Fully proved | Bracket preservation, switching, convergence |
| `Basic.lean` | 0 | 0 | — | Project root |
| **Total** | **136** | **4** | — | **9 of 11 targets fully proved** |

---

## The Main Proof Chain

The bisection convergence chain is the most sophisticated proof structure:

```mermaid
graph LR
    A["dx_halves_each_step ✅"] --> B["abs_dx_bisectStep ✅"]
    B --> C["abs_dx_after_k_steps ✅"]
    C --> D["bisect_terminates ✅"]
    D --> E["bisect_accuracy ✅"]
    F["midpoint_in_bracket ✅"] --> D
    G["iterateStep_succ_eq ✅"] --> C
```

The simple compounding round-trip remains the headline algebraic result:

```mermaid
graph LR
    A["simple_zero_time ✅"] --> D["simple_roundtrip_exact ✅"]
    B["simple_zero_rate ✅"] --> D
    C["simple_additive_excess ✅"] --> E["simple_monotone_rate ✅"]
    D --> F["Full Simple<br/>Compounding ✅"]
    E --> F
    G["continuousR_zero_time ✅"] --> H["continuousR_roundtrip ✅"]
    I["compoundContinuousR_pos ✅"] --> H
    H --> J["Full Continuous<br/>Compounding (ℝ) ✅"]
    K["continuousR_mul_periods ✅"] --> J
    L["continuousR_ge_simple ✅"] --> J
```

---

## Modelling Choices and Known Limitations

```mermaid
graph TD
    REAL["C++ Implementation<br/>QuantLib"]
    MODEL["Lean 4 Model<br/>FVSquad (8 files)"]
    PROOF["Lean Proofs<br/>87 proved"]
    REAL -->|"Modelled as"| MODEL
    MODEL -->|"Proved in"| PROOF
    NOTE1["✅ Included: formulas,<br/>compounding modes, day counts,<br/>interpolation, PDF/CDF, factorial,<br/>bisection, exp/log/erf (Mathlib ℝ)"]
    NOTE2["⚠️ Abstracted: Rat for reals,<br/>Int for dates, Nat for periods,<br/>ℝ for transcendentals,<br/>axiomatic CDF/invCDF"]
    NOTE3["❌ Omitted: calendar logic,<br/>QL_REQUIRE exceptions,<br/>FP rounding, class hierarchy,<br/>gamma function, I/O"]
    MODEL --- NOTE1
    MODEL --- NOTE2
    MODEL --- NOTE3
```

| Category | What's covered | What's abstracted/omitted |
|----------|---------------|--------------------------|
| Actual360 | Exact integer day-count formula | Calendar date construction (leap years, months) |
| Actual365Fixed | Exact integer day-count / 365.0 formula | Canadian Bond and No Leap variants, calendar logic |
| InterestRate (Simple/Compounded) | Exact rational arithmetic, all algebraic properties | IEEE 754 rounding |
| InterestRate (Continuous) | Real-valued exp/log via Mathlib ℝ (11 theorems) | IEEE 754 rounding |
| LinearInterpolation | Exact rational piecewise-linear model | Floating-point, extrapolation |
| Thirty360 | European convention day adjustment, exact formula | Other 30/360 conventions (US, Italian, etc.) |
| NormalDistribution | PDF via Gaussian formula, CDF via erf | Polynomial CDF approximation, gamma fallback |
| Factorial | Exact natural number factorial | Lookup-table optimisation, overflow |
| Bisection | Pure functional convergence model | Evaluation counting, exceptions, polymorphism |
| General | Pure mathematical formulas | I/O, serialization, observer pattern, market data |

---

## Spec-to-Implementation Complexity

| Target | Spec lines | Impl lines | Ratio | Assessment |
|--------|-----------|------------|-------|------------|
| `Actual360` | ~35 (8 theorems) | ~65 (C++ header) | **High** | Simple algebraic laws; impl has class hierarchy |
| `Actual365Fixed` | ~35 (8 theorems) | ~84 (C++ header) | **High** | Same algebraic structure as Actual360; Standard convention only |
| `InterestRate` | ~150 (30 theorems, 3 models) | ~360 (hpp + cpp) | **High** | Clean algebra constrains multi-mode implementation |
| `LinearInterpolation` | ~60 (7 theorems) | ~150 (hpp + templates) | **High** | Concise math constrains template machinery |
| `Thirty360` | ~80 (11 theorems) | ~200 (hpp + cpp) | **Medium-High** | Good for EU convention; full coverage needs all variants |
| `NormalDistribution` | ~100 (14 theorems) | ~300 (hpp + cpp) | **Medium-High** | Mathematical properties of PDF/CDF; impl uses polynomial approximation |
| `Factorial` | ~50 (10 theorems) | ~60 (hpp + cpp + table) | **High** | Growth/divisibility properties vs lookup-table impl |
| `Bisection` | ~120 (11 theorems) | ~80 (hpp) | **Medium** | Convergence proof longer than impl but captures non-obvious termination guarantee |

---

## Findings

### Bugs Found

No implementation bugs found across any of the 8 targets. All properties match the C++ exactly, confirmed by both formal proof and over 8,300 correspondence test cases.

### Formulation Issues

- The original InterestRate spec used `Float` throughout, making proofs impossible. **Reformulated** to use exact `Rat` + Mathlib `ℝ` — the triple-model approach is now the recommended pattern.
- NormalDistribution CDF derivative (`cdf_deriv_eq_pdf`) requires `HasDerivAt` for erf composition, which is not yet available in Mathlib for the specific composition needed.

### Interesting Structural Discoveries

- The `includeLastDay` flag breaks Actual360 additivity by exactly 1: `dayCount(d1,d2,T) + dayCount(d2,d3,T) = dayCount(d1,d3,T) + 1`. Proved formally.
- Simple compounding excess is exactly additive in time (linearity property).
- Continuous compounding ≥ simple compounding (`continuousR_ge_simple`) — textbook result formally verified.
- Day-31 adjustment in Thirty360 European is idempotent (`adjust_idempotent`).
- NormalDistribution CDF symmetry Φ(2μ−x) + Φ(x) = 1 proved via `erf_neg`.
- Bisection convergence rate `|dx_k| = |dx_0|/2^k` proved by induction — confirms exponential convergence.
- Actual365Fixed: translation invariance and full-year property (`dayCount(d, d+365) = 365`) proved — complements Actual360 day counter coverage.
- Bisection termination guarantee: if initial bracket allows sufficient fuel, the solver always returns a result within the requested accuracy.
- Factorial growth `n! ≥ 2^(n-1)` and `2^n | (2n)!` — non-trivial combinatorial identities.

---

## Project Timeline

```mermaid
timeline
    title FV Project Development
    section Phase 1 — Foundation (Runs 1–3)
        Research : 5 targets identified
        Actual360 : 8 theorems fully proved
        Correspondence : 2920 test cases
    section Phase 2 — Interest Rates (Runs 4–12)
        InterestRate : Rat model (14 theorems)
        Mathlib : Real model (11 theorems)
        CI : lean-ci.yml established
        Paper : Conference paper draft
    section Phase 3 — Expansion (Runs 13–17)
        LinearInterpolation : 7 theorems proved
        Thirty360 : 11 theorems proved
        Report : 50 theorems documented
    section Phase 4 — Distribution & Combinatorics (Runs 18–23)
        NormalDistribution : 14 theorems, CDF via erf
        Factorial : 10 theorems proved
        Correspondence : 1082 + 575 + 28 test cases
    section Phase 5 — Numerical Methods (Runs 24–28)
        Bisection : 11 theorems, convergence proved
        Termination : bisect_terminates proved
        Total : 87 proved, 4 sorry
    section Phase 6 — Expansion & Consolidation (Runs 29–35)
        Actual365Fixed : 8 theorems fully proved
        FloatingPointClose : Informal spec written
        BlackFormula : Informal spec written
        Correspondence : 8300+ test cases across 8 targets
        Total : 99 theorems, 4 sorry
    section Phase 7 — New Verifications (Runs 36–42)
        FloatingPointClose : 12 theorems fully proved
        BlackFormula : 13 theorems fully proved
        NewtonSafe : 13 theorems fully proved
        Correspondence : 8600+ test cases
        Total : 140 theorems, 4 sorry
```

---

## Toolchain

- **Prover**: Lean 4 v4.30.0-rc2 (via elan)
- **Libraries**: Mathlib (leanprover-community/mathlib4) — `Real.exp`, `Real.log`, `Real.erf`, `Nat.factorial`, algebra automation
- **CI**: `lean-ci.yml` with Mathlib caching (actions/checkout v6, cache v5, upload-artifact v7)
- **Build system**: Lake
- **Correspondence**: Route B (C++/Python executable tests), 8,300+ total cases

| Tactic | Usage |
|--------|-------|
| `simp` | Definitional unfolding, simplification |
| `omega` | Integer/natural arithmetic (day counters, factorial, bisection) |
| `rfl` | Definitional equality |
| `rw` | Rewriting with Mathlib and custom lemmas |
| `unfold` | Definition expansion |
| `exact` | Direct proof term application |
| `ring` | Ring arithmetic (rational algebra) |
| `linarith` | Linear arithmetic |
| `norm_num` | Numeric normalization |
| `induction` | Structural induction (factorial growth, bisection convergence) |
| `positivity` | Positivity goals |
| `gcongr` | Monotonicity via congruence |
| `constructor` | Existential/conjunction introduction |
| `cases` / `rcases` | Case analysis |
