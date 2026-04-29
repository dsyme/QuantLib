# Informal Specification: InterestRate (compoundFactor / impliedRate)

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `InterestRate` class encapsulates interest rate compounding algebra. Given a rate `r`,
a compounding convention, and (for discrete compounding) a frequency `n`, it computes:

- **Compound factor**: the growth multiplier over time period `t`
- **Implied rate**: the rate that produces a given compound factor over time `t`

These are inverse operations: `impliedRate(compoundFactor(r, t), t) = r`.

## Compounding Modes

| Mode | Compound Factor Formula | Domain |
|------|------------------------|--------|
| Simple | `1 + r·t` | r ∈ ℝ, t ≥ 0 |
| Compounded | `(1 + r/n)^(n·t)` | r > -n, t ≥ 0, n ∈ {1,2,3,4,6,12} |
| Continuous | `e^(r·t)` | r ∈ ℝ, t ≥ 0 |
| SimpleThenCompounded | Simple if `t ≤ 1/n`, else Compounded | same as Compounded |
| CompoundedThenSimple | Compounded if `t ≤ 1/n`, else Simple | same as Compounded |

## Preconditions

### compoundFactor(t)
- `t ≥ 0` (enforced by QL_REQUIRE)
- `r` is not null (enforced by QL_REQUIRE)
- For Compounded/hybrid modes: frequency was set at construction

### impliedRate(compound, comp, freq, t)
- `compound > 0` (enforced by QL_REQUIRE)
- If `compound ≠ 1`: `t > 0`
- If `compound = 1`: `t ≥ 0` (result is always `r = 0`)

## Postconditions

### compoundFactor(t)
- **Positivity**: result > 0 for all valid inputs
  - Simple: `1 + r·t > 0` when `r·t > -1` (always true for typical rates and t ≥ 0)
  - Compounded: `(1 + r/n)^(n·t) > 0` when `r > -n`
  - Continuous: `e^(r·t) > 0` always
- **Identity at t=0**: `compoundFactor(0) = 1` for all modes
- **Identity at r=0**: `compoundFactor(t) = 1` for all t when r = 0

### impliedRate(compound, comp, freq, t)
- Result rate `r'` satisfies: `compoundFactor(r', t) = compound`

## Invariants

- **Round-trip**: For each compounding mode, `impliedRate(compoundFactor(r, t), t).rate() = r`
  when inputs are in the valid domain.
- **Monotonicity in r**: `compoundFactor` is (weakly) increasing in `r` for fixed `t ≥ 0`
  - Simple: `d/dr (1 + r·t) = t ≥ 0` ✓
  - Compounded: `d/dr (1 + r/n)^(n·t) > 0` when `1 + r/n > 0` ✓
  - Continuous: `d/dr e^(r·t) = t·e^(r·t) ≥ 0` ✓
- **Monotonicity in t**: `compoundFactor` is (weakly) increasing in `t` for fixed `r ≥ 0`

## Edge Cases

| Case | compoundFactor | impliedRate |
|------|---------------|-------------|
| t = 0 | Returns 1.0 | compound=1 → r=0; compound≠1 → error (t>0 required) |
| r = 0 | Returns 1.0 | compound=1 → r=0 |
| Very large t | May overflow (double) | N/A |
| Negative r | Valid for Simple/Continuous; Compounded requires r > -n | Valid |
| SimpleThenCompounded boundary (t = 1/n) | Uses Simple formula | Uses Simple formula |

## Examples

| Mode | r | n | t | compoundFactor |
|------|---|---|---|---------------|
| Simple | 0.05 | — | 1.0 | 1.05 |
| Simple | 0.05 | — | 0.0 | 1.00 |
| Compounded | 0.05 | 2 | 1.0 | (1.025)² = 1.050625 |
| Continuous | 0.05 | — | 1.0 | e^0.05 ≈ 1.05127 |
| SimpleThenCompounded | 0.05 | 2 | 0.4 | 1 + 0.05·0.4 = 1.02 (Simple, t ≤ 0.5) |
| SimpleThenCompounded | 0.05 | 2 | 1.0 | (1.025)² = 1.050625 (Compounded, t > 0.5) |

## Inferred Intent

The design intent is a clean abstraction over multiple compounding conventions used in
fixed-income markets. The `impliedRate` function is the mathematical inverse of
`compoundFactor`, enabling rate conversion between conventions via:
```
equivalentRate(newComp, newFreq, t) = impliedRate(compoundFactor(t), newComp, newFreq, t)
```

## Open Questions

1. **CompoundedThenSimple boundary**: The C++ code uses `t > 1/n` for Simple and `t ≤ 1/n`
   for Compounded — note this is the **opposite** of SimpleThenCompounded (which uses `t ≤ 1/n`
   for Simple). Is this intentional? The naming suggests Compounded-first-then-Simple, which
   means Compounded for short periods and Simple for long — and indeed the code does this.
   But the boundary condition `>` vs `<=` could be a source of off-by-one behaviour at
   exactly `t = 1/n`.

2. **Floating-point round-trip**: The algebraic round-trip `impliedRate(compoundFactor(r,t),t) = r`
   holds exactly over reals but not necessarily over IEEE 754 doubles. Our Lean model will
   prove the real-valued identity; floating-point accuracy is out of scope.
