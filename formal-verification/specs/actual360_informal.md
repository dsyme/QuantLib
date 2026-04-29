# Informal Specification: Actual360 Day Counter

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `Actual360` day counter computes the year fraction between two dates using the
Act/360 convention: the actual number of calendar days divided by 360. An optional
`includeLastDay` flag adds one extra day to the count.

## Definition

```
dayCount(d1, d2)      = (d2 - d1) + (includeLastDay ? 1 : 0)
yearFraction(d1, d2)  = dayCount(d1, d2) / 360.0
```

where `d2 - d1` is the number of calendar days between the two dates.

## Preconditions

- `d1` and `d2` are valid dates
- Typically `d2 ≥ d1` (though the implementation does not enforce this)

## Postconditions

- `yearFraction(d1, d2) = dayCount(d1, d2) / 360`
- When `d2 ≥ d1` and `includeLastDay = false`: `yearFraction ≥ 0`
- When `d2 ≥ d1` and `includeLastDay = true`: `yearFraction > 0` (unless d1 = d2, then = 1/360)

## Invariants

- **Additivity** (without includeLastDay):
  `yearFraction(d1, d2) + yearFraction(d2, d3) = yearFraction(d1, d3)`
  This follows from `(d2-d1) + (d3-d2) = d3-d1`.

- **Additivity breaks with includeLastDay**:
  `dayCount(d1,d2) + dayCount(d2,d3) = (d2-d1+1) + (d3-d2+1) = (d3-d1) + 2 ≠ (d3-d1) + 1`
  So additivity does NOT hold when includeLastDay is true.

- **Consistency**: `yearFraction(d1, d2) * 360 = dayCount(d1, d2)` (exact in reals)

## Edge Cases

| Case | dayCount | yearFraction |
|------|----------|-------------|
| d1 = d2, includeLastDay=false | 0 | 0.0 |
| d1 = d2, includeLastDay=true | 1 | 1/360 |
| d2 < d1, includeLastDay=false | negative | negative |
| One day apart, includeLastDay=false | 1 | 1/360 |

## Examples

| d1 | d2 | includeLastDay | dayCount | yearFraction |
|----|----|----|----------|-------------|
| 2024-01-01 | 2024-07-01 | false | 182 | 182/360 ≈ 0.5056 |
| 2024-01-01 | 2024-07-01 | true | 183 | 183/360 ≈ 0.5083 |
| 2024-01-01 | 2024-01-01 | false | 0 | 0.0 |

## Inferred Intent

This is the simplest day counting convention. It is used extensively in money market
instruments (LIBOR, FRAs, swaps) where the 360-day year convention is standard.

## Open Questions

None — this is a straightforward implementation of a well-defined market convention.
