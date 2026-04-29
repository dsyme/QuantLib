# Informal Specification: InterestRate Compounding Algebra

🔬 *Lean Squad — informal specification for `dsyme/QuantLib`.*

## Target

**Component**: `InterestRate` class — `compoundFactor`, `discountFactor`, `impliedRate`
**Files**: `ql/interestrate.hpp`, `ql/interestrate.cpp`

## Purpose

The `InterestRate` class encapsulates interest rate compounding algebra. Given a rate `r`, a compounding convention, and optionally a frequency, it computes:
- The **compound factor**: how much $1 grows over time `t`
- The **discount factor**: the present value of $1 to be received at time `t`
- The **implied rate**: given a compound factor and time, recover the rate that produced it

## Compounding Modes

Six conventions are supported:

| Mode | `compoundFactor(t)` Formula | Domain |
|------|----------------------------|--------|
| **Simple** | `1 + r·t` | `t ≥ 0` |
| **Compounded** | `(1 + r/f)^(f·t)` | `t ≥ 0`, frequency `f > 0` |
| **Continuous** | `e^(r·t)` | `t ≥ 0` |
| **SimpleThenCompounded** | Simple if `t ≤ 1/f`, else Compounded | `t ≥ 0`, `f > 0` |
| **CompoundedThenSimple** | Compounded if `t ≤ 1/f`, else Simple | `t ≥ 0`, `f > 0` |

## Preconditions

- `t ≥ 0` (time must be non-negative)
- `r ≠ Null` (rate must be initialized)
- For Compounded/SimpleThenCompounded/CompoundedThenSimple: frequency `f` must be positive and not `Once`/`NoFrequency`
- For `impliedRate`: `compound > 0` and `t > 0` (or `t ≥ 0` if `compound = 1`)

## Postconditions

### compoundFactor(t)
1. **Positivity**: result `> 0` for all valid inputs
2. **Identity at zero**: `compoundFactor(0) = 1` for all modes
3. **Monotone in time**: for `r > 0`, `compoundFactor` is strictly increasing in `t`
4. **Monotone in rate**: for `t > 0`, `compoundFactor` is strictly increasing in `r` (for `r > -f` in Compounded mode)

### discountFactor(t)
5. **Inverse**: `discountFactor(t) = 1 / compoundFactor(t)`
6. **Range**: `0 < discountFactor(t) ≤ 1` for `r ≥ 0` and `t ≥ 0`

### impliedRate(compound, dc, comp, freq, t)
7. **Round-trip (compound → rate)**: `impliedRate(compoundFactor(r, t), comp, freq, t).rate() = r` for each mode
8. **Round-trip (rate → compound)**: `compoundFactor(impliedRate(c, comp, freq, t), t) = c` for each mode

## Invariants

- The `compoundFactor` and `impliedRate` functions are algebraic inverses for each compounding mode
- The `discountFactor` is always exactly `1/compoundFactor` — no independent computation
- SimpleThenCompounded and CompoundedThenSimple are continuous at the boundary `t = 1/f` (both branches give the same value there)

## Edge Cases

| Case | Expected |
|------|----------|
| `t = 0` | `compoundFactor = 1`, `discountFactor = 1` |
| `r = 0` | `compoundFactor = 1` for all `t` (Simple, Continuous); `1` for Compounded |
| `t = 1/f` (boundary) | SimpleThenCompounded and CompoundedThenSimple: both branches give same value |
| Very large `t` | Compounded/Continuous grow exponentially; Simple grows linearly |
| Negative `r` | `compoundFactor < 1` for `t > 0` (valid for Simple, Continuous; requires `r > -f` for Compounded) |

## Examples

With `r = 0.05` (5%), frequency `f = 2` (semi-annual):

| Mode | t = 0 | t = 0.5 | t = 1.0 | t = 2.0 |
|------|-------|---------|---------|---------|
| Simple | 1.0 | 1.025 | 1.05 | 1.10 |
| Compounded | 1.0 | 1.025 | 1.050625 | 1.10381289... |
| Continuous | 1.0 | 1.02532... | 1.05127... | 1.10517... |

## Inferred Intent

- The class is designed so that any rate can be converted to any other compounding convention via the chain: `rate → compoundFactor → impliedRate(newConvention)`
- The algebraic round-trip property is the **core correctness criterion** — everything else follows from it
- SimpleThenCompounded/CompoundedThenSimple exist because market conventions use simple interest for short periods and compounded for longer ones

## Open Questions

1. **CompoundedThenSimple**: The implementation uses Simple for `t > 1/f` and Compounded for `t ≤ 1/f`. Is this the intended convention? (It seems reversed from the name — "CompoundedThenSimple" suggests compounded first, then simple for longer periods, which is what the code does)
2. **Negative rates in Compounded mode**: When `r < -f`, `(1 + r/f)` becomes negative, and `pow` of a negative base with non-integer exponent is undefined. The code does not guard against this.
3. **Floating-point precision**: The round-trip `impliedRate(compoundFactor(r, t)) ≈ r` will have numerical error. Our Lean model uses exact reals, so the proofs cover the mathematical identity, not numerical accuracy.
