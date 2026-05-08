# Informal Specification: Rounding

🔬 *Lean Squad — automated formal verification.*

**Source**: `ql/math/rounding.hpp`, `ql/math/rounding.cpp`
**Target**: `Rounding::operator()(Decimal value)`

---

## Purpose

The `Rounding` class provides decimal rounding of floating-point numbers to a given
number of decimal places, supporting five rounding modes defined by the OMG specification
(OMG formal/00-06-29). It is used throughout QuantLib for currency rounding, price
rounding, and other financial calculations where precise decimal representation matters.

## Rounding Modes

The five modes (enum `Rounding::Type`) are:

| Mode | Behaviour |
|------|-----------|
| `None` | Return the value unmodified. |
| `Up` | Round away from zero: if any fractional part past the precision exists, increase the magnitude. |
| `Down` | Truncate toward zero: discard all digits past the precision. |
| `Closest` | Round to nearest: if the first discarded digit ≥ `digit` (default 5), round away from zero; otherwise truncate. This is OMG "round-up". |
| `Floor` | For **positive** values, behave like `Closest`; for **negative** values, behave like `Down` (truncate toward zero). |
| `Ceiling` | For **positive** values, behave like `Down` (truncate toward zero); for **negative** values, behave like `Closest`. |

> **Note on naming**: `Floor` rounds *positive* numbers away from zero and truncates
> negatives, while `Ceiling` does the opposite. These names differ from the standard
> mathematical floor/ceiling — the OMG spec warns about this.

## Parameters

- **precision** (`Integer`): number of decimal places to keep. Valid range [0, 16].
- **type** (`Rounding::Type`): one of the five modes above. Default: `Closest`.
- **digit** (`Integer`): the rounding digit threshold for `Closest`, `Floor`, `Ceiling` modes. Default: 5. The fractional part is compared to `digit / 10.0`.

## Preconditions

- `precision` ∈ {0, 1, …, 16}. Values outside this range cause undefined behaviour
  (the `fast_pow10` lookup table is only 17 entries; out-of-range access is masked to
  [0, 31] but entries 17–31 are zero, producing division by zero).
- `digit` should be in {1, 2, …, 9} for meaningful behaviour (0 makes `Closest` equivalent
  to `Up`; 10 makes it equivalent to `Down`).
- `value` is any finite `double`.

## Postconditions

Let `p = precision`, `d = digit`, and `mult = 10^p`.

For all modes except `None`:
1. **Result has at most `p` decimal places**: `result * mult` is an integer (up to floating-point representation).
2. **Magnitude relationship**: `|result| ≤ |value| + 10^(-p)` (the result is within one unit in the last place of the original).

Per-mode postconditions (using `frac = |value| * mult - floor(|value| * mult)`):

- **None**: `result = value` (identity).
- **Down**: `result = sign(value) * floor(|value| * mult) / mult`. Always truncates toward zero.
- **Up**: If `frac > 0`, `result = sign(value) * (floor(|value| * mult) + 1) / mult`. If `frac = 0`, `result = value`. Always rounds away from zero when there is a fractional part.
- **Closest**: If `frac ≥ d/10`, round away from zero; if `frac < d/10`, truncate toward zero.
- **Floor**: For `value ≥ 0`, same as `Closest`. For `value < 0`, same as `Down`.
- **Ceiling**: For `value ≥ 0`, same as `Down`. For `value < 0`, same as `Closest`.

## Invariants

- Rounding is **idempotent**: applying the same rounding twice yields the same result as applying it once: `round(round(x)) = round(x)`.
- `Down` never increases the magnitude: `|round_down(x)| ≤ |x|`.
- `Up` never decreases the magnitude: `|round_up(x)| ≥ |x|`.
- `None` is the identity function.
- When `digit = 5`, `Closest` is the standard "round half away from zero" rule.

## Edge Cases

| Input | Mode | Precision | Expected |
|-------|------|-----------|----------|
| `0.0` | any | any | `0.0` |
| `-0.0` | any | any | `-0.0` or `0.0` (IEEE 754) |
| Exact value (no fractional part past precision) | `Up` | any | value unchanged |
| Exact value | `Down` | any | value unchanged |
| Large value (e.g., 1e15) | any | 2 | value unchanged (already integer-like) |
| Very small value (e.g., 1e-17) | `Closest` | 16 | `0.0` |
| Negative value | `Floor` | p | truncates toward zero (not toward −∞) |
| Negative value | `Ceiling` | p | rounds away from zero (toward −∞) |
| `digit = 0` with `Closest` | — | — | rounds up always (frac ≥ 0 is always true except exact) |
| `digit = 10` with `Closest` | — | — | truncates always (frac < 1.0 is always true) |

## Examples (from test suite)

| Input | Precision | Closest | Up | Down | Floor | Ceiling |
|-------|-----------|---------|-----|------|-------|---------|
| 0.86313513 | 5 | 0.86314 | 0.86314 | 0.86313 | 0.86314 | 0.86313 |
| -7.64555346 | 1 | -7.6 | -7.7 | -7.6 | -7.6 | -7.6 |
| 0.13961605 | 2 | 0.14 | 0.14 | 0.13 | 0.14 | 0.13 |
| -1.06228670 | 1 | -1.1 | -1.1 | -1.0 | -1.0 | -1.1 |
| -0.26738058 | 1 | -0.3 | -0.3 | -0.2 | -0.2 | -0.3 |

## Inferred Intent

- The OMG-compliant rounding is specifically designed for **financial** applications where
  rounding rules must be deterministic and match industry standards.
- `Floor` and `Ceiling` are asymmetric by sign — they are not mathematical floor/ceiling
  but rather directional rounding that treats positive and negative numbers differently.
  This is intentional per the OMG specification.
- The `fast_pow10` lookup table is a performance optimisation avoiding `std::pow`.

## Open Questions

1. **Out-of-range precision**: precision values outside [0, 16] silently produce wrong
   results due to the LUT masking (`precision & 0x1F`). Should this be an assertion or error?
2. **NaN/Inf handling**: the code does not check for NaN or infinity inputs. Behaviour
   is whatever IEEE 754 arithmetic produces (likely NaN passthrough). Is this intentional?
3. **Rounding digit validation**: `digit` is not validated. Values outside [1, 9] produce
   edge-case behaviour. Should this be documented or asserted?
