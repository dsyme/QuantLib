> 🔬 *Lean Squad — automated formal verification for `dsyme/QuantLib`.*

**Status**: 🔄 IN PROGRESS — 24 theorems proved, 3 Lean files, 3 `sorry`, Lean 4 + Mathlib.

## Last Updated
- **Date**: 2026-04-30 09:43 UTC
- **Commit**: `5c48a7043`

---

## Executive Summary

Formal verification of QuantLib's quantitative finance primitives is progressing well using Lean 4 with Mathlib. The **Actual360** day counter is fully verified with 8 proved theorems and ~2,900 correspondence tests confirming exact match with C++. The **InterestRate** compounding module has **16 proved theorems** across three model layers: 11 over exact rationals (`Rat`), 5 over Mathlib reals (`ℝ`) for continuous compounding (exp/log), plus 3 sorry-guarded Float properties. Total: **24 proved theorems** across 2 targets, with 0 bugs found.

---

## Proof Architecture

The verification is organised into independent target modules, each modelling a specific QuantLib component. InterestRate uses a triple-model architecture: exact `Rat` for algebraic proofs, Mathlib `ℝ` for transcendental proofs, and `Float` for computational verification.

```mermaid
graph TD
    A["FVSquad.Basic<br/>(project root)"]
    B["FVSquad.Actual360<br/>8 theorems ✅"]
    C["FVSquad.InterestRate<br/>16 proved + 3 sorry"]
    A --> B
    A --> C
    C1["Rat model<br/>11 theorems ✅"]
    C2["Real model (Mathlib)<br/>5 theorems ✅"]
    C3["Float model<br/>3 sorry 🔄"]
    C --> C1
    C --> C2
    C --> C3
```

---

## What Was Verified

### Actual360 — Day Counter (1 file, 8 theorems)

Models the Act/360 day counting convention from `ql/time/daycounters/actual360.hpp`. Uses exact integer arithmetic — no approximation needed.

```mermaid
graph LR
    F1["Actual360.lean<br/>8 theorems ✅<br/>Additivity, non-negativity,<br/>antisymmetry, edge cases"]
```

**Key results**:
- `dayCount_additive`: `dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)` — the fundamental algebraic property
- `dayCount_antisymm`: `dayCount(d1,d2) = -dayCount(d2,d1)` — reversal symmetry
- `dayCount_includeLastDay_off_by_one`: proves the exact off-by-one when `includeLastDay=true`
- `dayCount_nonneg`, `dayCount_pos_includeLastDay`: non-negativity under ordering
- `dayCount_self`, `dayCount_self_includeLastDay`: zero/one at same date
- `yearFraction_eq_dayCount_div_360`: formula definition correctness

### InterestRate — Compounding Algebra (1 file, 16 proved + 3 sorry)

Models `InterestRate::compoundFactor` and `impliedRate` from `ql/interestrate.hpp/cpp`. Triple model: exact `Rat` for algebraic proofs, Mathlib `ℝ` for continuous compounding, `Float` for computational examples.

```mermaid
graph LR
    F2["InterestRate.lean<br/>16 proved ✅ + 3 sorry 🔄<br/>Round-trip, identities,<br/>monotonicity, exp/log"]
```

**Proved theorems over Rat** (11):
- `simple_roundtrip_exact`: `impliedSimpleQ(compoundSimpleQ(r, t), t) = r` when `t ≠ 0`
- `simple_zero_time`, `simple_zero_rate`: identity elements
- `compounded_zero_periods`, `compounded_zero_rate`: compounded identity elements
- `simple_additive_excess`: linearity of excess growth
- `simple_monotone_rate`: higher rate ⇒ higher compound factor
- `compounded_one_period`: reduction to `1 + r/n` for single period
- `simple_pos`: positivity under standard conditions
- `compounded_mul_periods`: `(1+r/n)^a · (1+r/n)^b = (1+r/n)^(a+b)`
- `simple_time_scaling`: excess return scales linearly with time

**Proved theorems over ℝ (Mathlib)** (5):
- `compoundContinuousR_pos`: `exp(r·t) > 0` via `Real.exp_pos`
- `continuousR_roundtrip`: `log(exp(r·t))/t = r` via `Real.log_exp`
- `continuousR_zero_time`, `continuousR_zero_rate`: identity elements via `Real.exp_zero`
- `continuousR_mul_periods`: `exp(r·(s+t)) = exp(r·s)·exp(r·t)` via `Real.exp_add`

**Sorry-guarded** (require Mathlib or transcendental functions):
- `compoundContinuous_pos`: `e^(r·t) > 0` — needs `Float.exp_pos` or `Real.exp_pos`
- `continuous_roundtrip`: `ln(e^(r·t))/t = r` — needs `Real.log_exp`
- `compounded_roundtrip`: `((1+r/n)^(nt))^(1/(nt)) = r` — needs fractional exponents

---

## File Inventory

| File | Proved | Sorry | Phase | Key result |
|------|--------|-------|-------|------------|
| `Actual360.lean` | 8 | 0 | ✅ Fully proved | Additivity, antisymmetry, non-negativity |
| `InterestRate.lean` | 16 | 3 | 🔄 Partial | Round-trip, identities, monotonicity, exp/log |
| `Basic.lean` | 0 | 0 | — | Project root |
| **Total** | **24** | **3** | — | — |

---

## The Main Proof Chain

The simple compounding round-trip is the headline result for InterestRate:

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
```

The round-trip theorem states: for any rate `r` and time `t ≠ 0`,
```
impliedSimpleQ (compoundSimpleQ r t) t = r
```

---

## Modelling Choices and Known Limitations

```mermaid
graph TD
    REAL["C++ Implementation<br/>QuantLib"]
    MODEL["Lean 4 Model<br/>FVSquad"]
    PROOF["Lean Proofs"]
    REAL -->|"Modelled as"| MODEL
    MODEL -->|"Proved in"| PROOF
    NOTE1["✅ Included: formulas,<br/>compounding modes,<br/>day count arithmetic,<br/>exp/log (via Mathlib ℝ)"]
    NOTE2["⚠️ Abstracted: Rat for reals,<br/>Int for dates, Nat for periods,<br/>ℝ for continuous compounding"]
    NOTE3["❌ Omitted: calendar logic,<br/>QL_REQUIRE exceptions,<br/>FP rounding"]
    MODEL --- NOTE1
    MODEL --- NOTE2
    MODEL --- NOTE3
```

| Category | What's covered | What's abstracted/omitted |
|----------|---------------|--------------------------|
| Actual360 | Exact integer day-count formula | Calendar date construction (leap years, months) |
| InterestRate (Simple) | Exact rational arithmetic, all algebraic properties | IEEE 754 rounding |
| InterestRate (Compounded) | Zero-rate and zero-period identities | Fractional exponents, n-th roots |
| InterestRate (Continuous) | Real-valued exp/log via Mathlib ℝ (5 theorems proved) | IEEE 754 rounding |
| General | Pure mathematical formulas | I/O, serialization, observer pattern, market data |

---

## Spec-to-Implementation Complexity

| Target | Spec lines | Impl lines | Ratio | Assessment |
|--------|-----------|------------|-------|------------|
| `Actual360` | ~35 (8 theorems + types) | ~65 (C++ header) | **High** | Spec captures full correctness with simple algebraic laws; impl has class hierarchy overhead |
| `InterestRate` | ~100 (16 theorems + types across 3 models) | ~360 (hpp + cpp) | **High** | Clean algebraic properties constrain a multi-mode implementation. Triple model covers rational, real, and computational layers |

---

## Findings

### Bugs Found

No implementation bugs found so far. All Actual360 properties match the C++ exactly, confirmed by both formal proof and ~2,900 correspondence test cases. InterestRate's algebraic laws hold over exact rationals, and continuous compounding is now proved over Mathlib's ℝ.

### Formulation Issues

The original InterestRate spec used `Float` throughout, making proofs impossible without Float-specific axioms. **Run 5 reformulated the model** to use exact `Rat` for provable properties. **Run 9 added Mathlib** and introduced a third layer using `ℝ` for transcendental functions, enabling 5 new continuous compounding proofs. This triple-model approach (Rat + ℝ + Float) is the recommended pattern for future targets.

### Interesting Structural Discoveries

- The `includeLastDay` flag breaks additivity in a precise way: `dayCount(d1,d2,T) + dayCount(d2,d3,T) = dayCount(d1,d3,T) + 1`. This was proved formally and confirms the design is intentional, not a bug.
- Simple compounding's excess over 1 is exactly additive in time: `(1+r(s+t))-1 = ((1+rs)-1) + ((1+rt)-1)`. This is the linearity property that makes simple interest "simple."

---

## Project Timeline

```mermaid
timeline
    title FV Project Development
    section Run 1 (2026-04-29)
        Research : 5 targets identified
        Informal Specs : Actual360 and InterestRate
    section Run 2 (2026-04-29)
        Lean Specs : Actual360 fully proved (8 theorems)
        Lean Specs : InterestRate specs (6 sorry)
    section Run 3 (2026-04-29)
        Correspondence : Actual360 tests (2900 cases)
        Report : Project report created
    section Run 4 (2026-04-29)
        Proofs : InterestRate 7 new proofs (Rat model)
        Report : Updated with proof inventory
    section Run 5-8 (2026-04-30)
        CI : lean-ci.yml created
        Paper : Conference paper draft
        Proofs : 4 more Rat proofs + critique
    section Run 9 (2026-04-30)
        Mathlib : Added Mathlib dependency
        Proofs : 5 Real-valued theorems (exp/log)
    section Run 10 (2026-04-30)
        Correspondence : Review updated for triple model
        Report : Updated to 24 proved theorems
```

---

## Toolchain

- **Prover**: Lean 4 v4.30.0-rc2
- **Libraries**: Mathlib (leanprover-community/mathlib4) — `Real.exp`, `Real.log`, algebra automation
- **CI**: `lean-ci.yml` with Mathlib caching via `actions/cache`
- **Build system**: Lake

| Tactic | Usage |
|--------|-------|
| `simp` | Definitional unfolding, simplification |
| `omega` | Integer arithmetic (all Actual360 proofs) |
| `rfl` | Definitional equality |
| `rw` | Rewriting with lemmas (`Rat.add_comm`, `Rat.mul_div_cancel`, etc.) |
| `unfold` | Definition expansion |
| `exact` | Direct proof term application |
| `induction` | Structural induction (e.g., `rat_one_pow`) |
