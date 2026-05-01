# Informal Specification: Actual365Fixed Day Counter

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

The Actual/365 (Fixed) day counter computes year fractions by dividing the actual number of days between two dates by 365. This is the **Standard** convention variant.

**Source**: `ql/time/daycounters/actual365fixed.hpp` (class `Actual365Fixed::Impl`)

## Conventions

QuantLib implements three conventions under `Actual365Fixed`:

1. **Standard** — `yearFraction(d1, d2) = daysBetween(d1, d2) / 365.0`
2. **Canadian Bond** — adjusts for reference period and frequency
3. **No Leap** — counts days excluding Feb 29

This spec covers the **Standard** convention only (the simplest and most widely used).

## Preconditions

- `d1`, `d2` are valid dates (modelled as integers — day offsets from epoch)

## Postconditions

- `dayCount(d1, d2) = d2 - d1`
- `yearFraction(d1, d2) = dayCount(d1, d2) / 365.0`

## Invariants

- **Non-negativity**: `dayCount(d1, d2) ≥ 0` when `d2 ≥ d1`
- **Additivity**: `dayCount(d1, d2) + dayCount(d2, d3) = dayCount(d1, d3)`
- **Anti-symmetry**: `dayCount(d1, d2) = -dayCount(d2, d1)`
- **Same-date**: `dayCount(d, d) = 0`
- **Formula correctness**: `yearFraction` is exactly `dayCount / 365`

## Edge Cases

- Same date: dayCount = 0, yearFraction = 0
- One full year (365 days): yearFraction = 1.0
- Negative direction (d1 > d2): dayCount < 0

## Examples

| d1 | d2 | dayCount | yearFraction |
|----|-----|----------|-------------|
| 0  | 365 | 365      | 1.0         |
| 0  | 182 | 182      | ≈0.4986     |
| 0  | 0   | 0        | 0.0         |

## Inferred Intent

The Standard convention is deliberately simple — no leap year logic, no reference period. It uses 365 as a fixed divisor regardless of the actual calendar.

## Open Questions

None — the Standard convention is unambiguous.
