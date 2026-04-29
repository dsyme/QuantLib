# Correspondence Tests: Actual360

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

These tests validate that the Lean 4 formal model (`FVSquad.Actual360`) corresponds
to the C++ implementation (`ql/time/daycounters/actual360.hpp`).

## Approach (Route B — Executable Correspondence)

Since QuantLib is a C++ codebase (Aeneas not applicable), we use Route B:
a standalone C++ test harness that reimplements the minimal Actual360 logic
and verifies it against the same test fixtures used in the Lean model's `#eval` checks.

### What is tested

1. **Point cases** (19 cases): specific input pairs compared against expected values
   matching the Lean `#eval` outputs and the informal spec.
2. **Additivity sweep** (~1331 cases): `dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)`
   for `includeLastDay=false`, matching `theorem dayCount_additive`.
3. **Antisymmetry sweep** (~900 cases): `dayCount(a,b) = -dayCount(b,a)`
   for `includeLastDay=false`, matching `theorem dayCount_antisymm`.
4. **IncludeLastDay off-by-one sweep** (~729 cases): `dayCount(d1,d2,true) + dayCount(d2,d3,true) = dayCount(d1,d3,true) + 1`,
   matching `theorem dayCount_includeLastDay_off_by_one`.

### What is NOT tested

- Full QuantLib date arithmetic (leap years, month lengths). The Lean model abstracts
  dates as integers, and the C++ `dayCount` uses `d2-d1` which is also an integer difference.
  The correspondence is at the formula level, not the calendar level.

## Build and Run

```bash
g++ -std=c++17 -O2 -o test_actual360 test_actual360.cpp
./test_actual360
```

## Correspondence to Lean Theorems

| C++ Test | Lean Theorem | Property |
|----------|-------------|----------|
| Point cases (dayCount) | `dayCount_nonneg`, `dayCount_self`, etc. | Formula correctness |
| Point cases (yearFraction) | `yearFraction_eq_dayCount_div_360` | Formula correctness |
| Additivity sweep | `dayCount_additive` | `(d2-d1) + (d3-d2) = (d3-d1)` |
| Antisymmetry sweep | `dayCount_antisymm` | `dayCount(a,b) = -dayCount(b,a)` |
| Off-by-one sweep | `dayCount_includeLastDay_off_by_one` | `dc(d1,d2,T) + dc(d2,d3,T) = dc(d1,d3,T) + 1` |

## Source Provenance

The C++ logic in `test_actual360.cpp` is a direct copy of the formulas from
`ql/time/daycounters/actual360.hpp` (commit at time of writing). The Lean model
in `formal-verification/lean/FVSquad/Actual360.lean` models the same formulas.
