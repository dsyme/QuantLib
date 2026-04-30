# Correspondence Tests: InterestRate

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

These tests validate that the Lean 4 formal model (`FVSquad.InterestRate`)
corresponds to the C++ implementation (`ql/interestrate.cpp`).

## Approach (Route B — Executable Correspondence)

Since QuantLib is a C++ codebase (Aeneas not applicable), we use Route B:
a standalone C++ test harness that reimplements both the C++ formulas and the
Lean Float model formulas, then verifies they produce identical results.

### What is tested

1. **compoundFactor point cases** (344 cases): Simple, Compounded, Continuous,
   SimpleThenCompounded, and CompoundedThenSimple across a grid of rates, times,
   and frequencies. Each case verifies the C++ formula equals the Lean model formula.

2. **impliedRate point cases** (240 cases): Simple, Compounded, and Continuous
   implied rates for a grid of compound factors, times, and frequencies.

3. **Round-trip sweep** (432 cases): `impliedRate(compoundFactor(r, t), ..., t) ≈ r`
   for Simple, Compounded, and Continuous modes. Tolerance: 1e-10.
   Validates `simple_roundtrip_exact` (Lean theorem) holds computationally.

4. **Monotonicity** (378 cases): higher rate ⟹ higher compound factor for all
   compounding modes. Validates `simple_monotone_rate` and `continuousR_monotone_rate`.

### What is NOT tested

- **Fractional compounding periods**: The C++ uses `std::pow(1+r/n, n*t)` with
  real-valued exponent. The Lean Rat model restricts to `Nat` exponent. This
  divergence is documented in CORRESPONDENCE.md.
- **IEEE 754 edge cases**: NaN, ±Inf, denormals.
- **Error handling paths**: QL_REQUIRE checks (negative time, null rate, etc.).
  The Lean model uses `Option` instead of exceptions.
- **Day counter integration**: The Lean model takes `Float` time directly.

## Build and Run

```bash
g++ -std=c++17 -O2 -lm -o test_interestrate test_interestrate.cpp
./test_interestrate
```

## Correspondence to Lean Theorems

| C++ Test | Lean Theorem | Property |
|----------|-------------|----------|
| Simple point cases | `simple_zero_time`, `simple_zero_rate` | Formula correctness |
| Compounded point cases | `compounded_zero_periods`, `compounded_one_period` | Formula correctness |
| Round-trip sweep | `simple_roundtrip_exact` | `impliedRate(compoundFactor(r,t),t) = r` |
| Monotonicity sweep | `simple_monotone_rate`, `continuousR_monotone_rate` | Higher rate ⟹ higher factor |

## Source Provenance

The C++ logic in `test_interestrate.cpp` is a direct copy of the formulas from
`ql/interestrate.cpp` (lines 45–107). The Lean model in
`formal-verification/lean/FVSquad/InterestRate.lean` models the same formulas.

## Results

- **Total**: 1394 cases
- **Passed**: 1394
- **Failed**: 0
- **Tolerance**: 1e-12 for point cases, 1e-10 for round-trips
