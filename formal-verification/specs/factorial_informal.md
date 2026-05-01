# Informal Specification: Factorial

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `Factorial` class provides two static methods:
- `Factorial::get(n)` — returns `n!` (the factorial of natural number `n`)
- `Factorial::ln(n)` — returns `ln(n!)` (the natural logarithm of `n!`)

## Implementation

- For `n ≤ 27`: lookup from a precomputed table of exact double values
- For `n > 27`: compute via `exp(GammaFunction::logValue(n+1))` (using `Γ(n+1) = n!`)

## Preconditions

- `n` is a natural number (non-negative integer)

## Postconditions

- `get(n)` returns `n!` (the product `1 × 2 × ... × n`, with `0! = 1`)
- `ln(n)` returns `ln(n!)`
- For `n ≤ 27`, the result is exact (within floating-point representation)
- `get(n) > 0` for all valid `n`

## Key Properties

1. **Base case**: `get(0) = 1`
2. **Recurrence**: `get(n+1) = (n+1) * get(n)` for all `n ≥ 0`
3. **Positivity**: `get(n) > 0` for all `n`
4. **Monotonicity**: `get(n+1) ≥ get(n)` for all `n ≥ 0`
5. **Log relationship**: `ln(n) = log(get(n))`
6. **Growth**: `get(n) ≥ 2^(n-1)` for `n ≥ 1`

## Spec-to-Implementation Complexity Ratio

**High** — The specification is a one-line recurrence (`n! = n × (n-1)!`), while the
implementation uses a precomputed lookup table and gamma function fallback for efficiency.

## Open Questions

- None. The mathematical definition of factorial is unambiguous.
