# Correspondence Tests: Actual365Fixed (Standard Convention)

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

These tests validate that the Lean 4 formal model (`FVSquad.Actual365Fixed`) corresponds
to the C++ implementation (`ql/time/daycounters/actual365fixed.hpp`, Standard convention).

## Approach (Route B — Executable Correspondence)

Since QuantLib is a C++ codebase (Aeneas not applicable), we use Route B:
a standalone C++ test harness that reimplements the minimal Actual365Fixed Standard
logic and verifies it against the same test fixtures used in the Lean model's `#eval` checks.

### What is tested

1. **Point cases** (11 cases): specific input pairs compared against expected values
   matching the Lean `#eval` outputs.
2. **Additivity sweep** (1331 cases): `dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)`,
   matching `theorem dayCount_additive`.
3. **Antisymmetry sweep** (441 cases): `dayCount(d1,d2) = -dayCount(d2,d1)`,
   matching `theorem dayCount_antisymm`.
4. **Translation invariance** (125 cases): `dayCount(d1+k, d2+k) = dayCount(d1,d2)`,
   matching `theorem dayCount_translate`.
5. **Full year** (101 cases): `dayCount(d, d+365) = 365`,
   matching `theorem dayCount_full_year`.
6. **Strict monotonicity** (275 cases): `d2 < d3 → dayCount(d1,d2) < dayCount(d1,d3)`,
   matching `theorem dayCount_strict_mono`.

**Total: 2295 test cases.**

### What is NOT tested

- Canadian Bond and No Leap conventions (not modelled in Lean).
- Full QuantLib date arithmetic (leap years, month lengths). The Lean model abstracts
  dates as integers.

## Build and Run

```bash
g++ -std=c++17 -O2 -o test_actual365fixed test_actual365fixed.cpp
./test_actual365fixed
```

## Correspondence to Lean Theorems

| Lean Theorem | Test Section | Cases |
|---|---|---|
| `dayCount_additive` | Additivity sweep | 1331 |
| `dayCount_antisymm` | Antisymmetry sweep | 441 |
| `dayCount_translate` | Translation invariance | 125 |
| `dayCount_full_year` | Full year | 101 |
| `dayCount_strict_mono` | Strict monotonicity | 275 |
| `yearFraction_eq_dayCount_div_365` | Point cases | 11 |
| `dayCount_nonneg` | (implied by point cases with d2 ≥ d1) | — |
| `dayCount_self` | Point case (same date) | 1 |
