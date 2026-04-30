# Thirty360 Day Counter — Informal Specification

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `Thirty360` day counter computes the number of days between two dates using the "30/360" convention family, where each month is treated as having 30 days and a year as 360 days. The year fraction is always `dayCount(d1, d2) / 360`.

Multiple conventions exist (US, BondBasis/ISMA, European/Eurobond, Italian, ISDA/German, NASD) that differ in how they adjust day-of-month values at the boundaries (day 31, end-of-February).

## Core Formula

All conventions share the same final computation:

```
dayCount(d1, d2) = 360 × (Y2 - Y1) + 30 × (M2 - M1) + (D2' - D1')
```

where `D1'` and `D2'` are the adjusted day values after applying convention-specific rules.

## Conventions and Adjustment Rules

### European (30E/360)
- If D1 = 31, set D1 = 30
- If D2 = 31, set D2 = 30

**Simplest convention**: both endpoints capped at 30.

### ISMA / BondBasis
- If D1 = 31, set D1 = 30
- If D2 = 31 **and** D1 = 30 (after adjustment), set D2 = 30

### US (30/360)
- If D1 is last day of February, then:
  - If D2 is also last day of February, set D2 = 30
  - Set D1 = 30
- If D2 = 31 and D1 ≥ 30 (after above adjustments), set D2 = 30
- If D1 = 31, set D1 = 30

**Note**: Order of checks matters. February end-of-month is checked first.

### Italian
- If D1 = 31, set D1 = 30
- If D2 = 31, set D2 = 30
- If M1 = February and D1 > 27, set D1 = 30
- If M2 = February and D2 > 27, set D2 = 30

### ISDA / German (30E/360 ISDA)
- If D1 = 31, set D1 = 30
- If D2 = 31, set D2 = 30
- If D1 is last day of February, set D1 = 30
- If D2 is last day of February **and** d2 ≠ terminationDate, set D2 = 30

**Note**: ISDA convention takes a `terminationDate` parameter; the end-of-Feb rule does not apply when d2 equals the termination date.

### NASD
- If D1 = 31, set D1 = 30
- If D2 = 31 and D1 ≥ 30, set D2 = 30
- If D2 = 31 and D1 < 30, set D2 = 1 and M2 = M2 + 1

## Preconditions

- `d1` and `d2` are valid calendar dates
- For ISDA convention: `terminationDate` is a valid date (may be null/empty in QuantLib, meaning no special handling)
- No restriction on ordering: `d1` may be before or after `d2`

## Postconditions

- `dayCount(d1, d2)` returns an integer (may be negative if d2 < d1)
- `yearFraction(d1, d2) = dayCount(d1, d2) / 360.0`

## Invariants and Properties

### Universal (all conventions)

1. **Same-date**: `dayCount(d, d) = 0` for all dates d
2. **Year fraction formula**: `yearFraction(d1, d2) = dayCount(d1, d2) / 360`
3. **Full year**: for dates exactly one year apart on "normal" days (not month-end), `dayCount = 360`
4. **Full month**: for dates exactly one month apart on day ≤ 28, `dayCount = 30`

### European (simplest — strongest algebraic properties)

5. **Antisymmetry**: `dayCount(d1, d2) = -dayCount(d2, d1)` — holds because adjustments are symmetric (both endpoints treated identically)
6. **Additivity**: `dayCount(d1, d2) + dayCount(d2, d3) = dayCount(d1, d3)` — **expected to hold** because each date's adjustment depends only on itself, not on the other endpoint
7. **Bounded day difference**: within the same month-year, `|dayCount| ≤ 30`

### ISMA/BondBasis

8. **No antisymmetry**: the asymmetric rule (D2 adjusted only if D1 was adjusted) breaks symmetry. `dayCount(d1, d2) ≠ -dayCount(d2, d1)` in general when day-31 dates are involved.

### US

9. **February special case**: when both dates are end-of-Feb, both get mapped to 30 — so `dayCount(end-Feb-Y1, end-Feb-Y2)` is a multiple of 360 for dates exactly N years apart.

### NASD

10. **Month rollover**: unique among conventions — can increment the month of D2. This means `dayCount` result can be larger than other conventions for the same date pair.

## Edge Cases

- **Leap year February**: Feb 29 is "last of February" in leap years; Feb 28 is "last of February" in non-leap years.
- **D1 = D2 = 31**: European → both become 30, result = 0. ISMA → D1=30, then D2=30 (since D1=30), result = 0. US → D1=30 (since 31≥30 after no Feb check), D2=30, result = 0.
- **Feb 28 non-leap → Feb 28 next year non-leap** (US): both are last-of-Feb → both become 30 → dayCount = 360.
- **Feb 29 leap → Feb 28 next year non-leap** (US): D1 is last-of-Feb → D1=30. D2 is last-of-Feb → D2=30. dayCount = 360.
- **NASD day-31 rollover**: Date(31, Jan) to Date(31, Mar): D1=30 (rule 1), D2=31 and D1≥30 → D2=30. Result = 60. But Date(15, Jan) to Date(31, Mar): D1=15, D2=31 and D1<30 → D2=1, M2=April. Result = 360×0 + 30×(4-1) + (1-15) = 76.

## Examples (from ISDA test cases)

### BondBasis (ISMA)
| Start | End | Expected |
|-------|-----|----------|
| 2006-08-20 | 2007-02-20 | 180 |
| 2006-08-31 | 2007-02-28 | 178 |
| 2007-02-28 | 2007-08-31 | 183 |
| 2006-01-31 | 2006-02-28 | 28 |
| 2006-09-30 | 2006-10-31 | 30 |

### Eurobond (European)
| Start | End | Expected |
|-------|-----|----------|
| 2006-08-20 | 2007-02-20 | 180 |
| 2006-08-31 | 2007-02-28 | 178 |
| 2007-02-28 | 2007-08-31 | 182 |

## Open Questions

1. **Additivity for non-European conventions**: Does `dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)` hold for ISMA/US? The endpoint-dependent adjustments make this unlikely in general — worth verifying formally (potential bug-catching property).
2. **NASD month overflow**: When NASD increments M2, does it handle December→January year rollover correctly? The code uses `mm2++` without year adjustment — potential bug if dd2=31 and mm2=12 and dd1<30.
3. **ISDA terminationDate equality**: Does the code use value equality or reference equality for `d2 != terminationDate_`? (Value equality based on code inspection.)

## Inferred Intent

The 30/360 conventions exist to simplify interest calculations by normalising months to 30 days. The different conventions arose from different market practices (US bond market, Eurobond market, Italian market, ISDA standards). The implementation faithfully follows ISDA documentation (referenced in test file).

The European convention is the "cleanest" algebraically and the best target for formal verification of structural properties. The US and NASD conventions have the most complex edge cases and are the most likely to harbour bugs.
