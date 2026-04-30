# Proof Utility Critique

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Last Updated
- **Date**: 2026-04-30 07:54 UTC
- **Commit**: `c8504b8ec`

---

## Overall Assessment

The formal verification effort has produced **18 proved theorems** across 2 targets (Actual360 and InterestRate), covering fundamental algebraic properties of day counting and interest rate compounding. The proofs are sound and meaningful — they verify the mathematical correctness of core financial formulas that, if broken, would cause widespread calculation errors. The project is in a healthy early state with strong foundations, though the highest-value remaining work lies in extending coverage to more complex compounding modes and additional targets.

---

## Proved Theorems

| Theorem | File | Level | Bug-catching | Spec:Impl Ratio | Notes |
|---------|------|-------|-------------|-----------------|-------|
| `dayCount_nonneg` | Actual360.lean | Mid | Medium | High | Catches sign errors in subtraction |
| `dayCount_additive` | Actual360.lean | Mid | High | High | Fundamental composability — catches off-by-one in date arithmetic |
| `dayCount_antisymm` | Actual360.lean | Mid | Medium | High | Directional consistency |
| `dayCount_pos_includeLastDay` | Actual360.lean | Mid | Medium | High | Boundary condition coverage |
| `dayCount_includeLastDay_off_by_one` | Actual360.lean | Mid | High | High | Documents the non-additivity of includeLastDay — high bug potential |
| `dayCount_self` | Actual360.lean | Low | Low | High | Trivial but good sanity check |
| `dayCount_self_includeLastDay` | Actual360.lean | Low | Low | High | Edge case coverage |
| `simple_roundtrip_exact` | InterestRate.lean | High | High | High | Inverse relationship — catches formula errors in either direction |
| `simple_zero_time` | InterestRate.lean | Low | Low | High | Identity element — trivial |
| `simple_zero_rate` | InterestRate.lean | Low | Low | High | Identity element — trivial |
| `compounded_zero_periods` | InterestRate.lean | Low | Low | High | Identity element |
| `compounded_zero_rate` | InterestRate.lean | Low | Medium | High | Zero-rate invariant across all period counts |
| `simple_additive_excess` | InterestRate.lean | Mid | High | High | Linearity — catches subtle formula drift |
| `simple_monotone_rate` | InterestRate.lean | Mid | High | High | Monotonicity — catches sign/comparison bugs |
| `compounded_one_period` | InterestRate.lean | Low | Medium | High | Reduction to simple form |
| `simple_pos` | InterestRate.lean | Mid | Medium | High | Positivity precondition |
| `compounded_mul_periods` | InterestRate.lean | High | High | High | Multiplicative structure — key algebraic law |
| `simple_time_scaling` | InterestRate.lean | Mid | High | High | Linearity of excess return in time |

---

## Spec-to-Implementation Complexity Assessment

| Target | Spec Lines (theorems + types) | Impl Lines (C++) | Ratio | Assessment |
|--------|------------------------------|------------------|-------|------------|
| Actual360 | ~40 (7 theorems, 2 defs) | ~15 (dayCount + yearFraction) | **High** | Spec captures 7 algebraic laws; impl is simple but the *correctness criteria* are non-trivial to state. The proofs give high confidence. |
| InterestRate | ~80 (11 theorems, 3 defs) | ~120 (compoundFactor + impliedRate, 5 modes) | **High** | Clean algebraic properties constrain a multi-mode implementation. The spec is obviously correct by inspection; the impl has branching complexity. |

Both targets are in the FV sweet spot: simple, inspectable specs constraining non-trivial implementations. The proved properties would catch real formula errors (wrong signs, missed terms, incorrect exponents).

---

## Gaps and Recommendations

### High Priority

1. **InterestRate: Compounded round-trip** — The most valuable unproved theorem. Would require either Mathlib (for `Real` and `rpow` inverse) or a reformulation restricted to Nat exponents with a custom n-th root definition. Consider adding a Rat-only formulation: `impliedCompoundedQ` that inverts `compoundCompoundedQ` for `Nat` periods.

2. **LinearInterpolation** (new target) — High spec-to-impl ratio. Core properties: boundary values match data points, monotonicity preservation, continuity. Implementation is ~80 lines of C++ with index searching; spec would be ~10 lines of algebraic conditions.

3. **InterestRate: Compounded monotonicity** — Prove that for fixed positive n, t, and rate r₁ ≤ r₂ ≥ 0, we have `compoundCompoundedQ r₁ n p ≤ compoundCompoundedQ r₂ n p`. This is a high-value property but requires induction over Nat powers with an ordering argument.

### Medium Priority

4. **Thirty360** (new target) — Complex case analysis with known industry bugs. High bug-catching potential but spec would be complex (many date conventions).

5. **InterestRate correspondence tests** — No runnable correspondence tests exist for InterestRate. Adding tests like Actual360's would validate the Rat model against C++ outputs.

---

## Concerns

1. **Float theorems are unprovable without Mathlib**: The 3 sorry-guarded theorems (`compoundContinuous_pos`, `continuous_roundtrip`, `compounded_roundtrip`) operate over `Float` and genuinely cannot be proved in Lean stdlib. They require either:
   - Mathlib's `Real.exp_pos`, `Real.log_exp` (network-blocked in CI)
   - Custom axioms (would be unsound)
   - Reformulation over `Rat` (impossible for transcendentals)
   
   **Recommendation**: Leave these as documented aspirational goals. They are not vacuous — the *statements* are correct and serve as documentation. If Mathlib becomes available, they are straightforward to prove.

2. **No vacuity concerns**: All proved theorems are over exact `Rat` arithmetic with clear correspondence to C++ formulas. None rely on dubious model approximations. The Nat exponent restriction for `compoundCompoundedQ` is clearly documented and does not invalidate the proofs for their stated domain.

3. **Correspondence gap for InterestRate**: While Actual360 has 2920 validated test cases, InterestRate has no runnable correspondence tests. The Rat model's correctness is argued by inspection (formulas are identical), but executable evidence would strengthen confidence.

---

## Positive Findings

- **The round-trip theorem** (`simple_roundtrip_exact`) proves that `impliedSimpleQ` is a perfect inverse of `compoundSimpleQ`. This is exactly the kind of property that catches formula transcription errors — if either formula had a sign error or missing term, the round-trip would fail.

- **The additivity theorem** for Actual360 (`dayCount_additive`) formally confirms that day counting composes correctly over intervals. Off-by-one errors in date arithmetic are a notorious source of financial calculation bugs.

- **The new `compounded_mul_periods` theorem** (added this run) proves the fundamental multiplicative structure of compound interest: compounding over a+b periods equals compounding over a periods times compounding over b periods. This is a high-value structural property.

- **No bugs found** — all specified properties hold. This is itself a positive finding: the mathematical core of QuantLib's interest rate and day counting is correctly implemented (within the modelled domain).
