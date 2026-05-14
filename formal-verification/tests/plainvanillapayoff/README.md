# Correspondence Tests: PlainVanillaPayoff

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

These tests validate that the Lean 4 formal model (`FVSquad.PlainVanillaPayoff`) corresponds
to the C++ implementation (`ql/instruments/payoffs.cpp` lines 91–99).

## Approach (Route B — Executable Correspondence)

Since QuantLib is a C++ codebase (Aeneas not applicable), we use Route B:
a standalone C++ test harness that reimplements the minimal PlainVanillaPayoff logic
and verifies it against the same properties proved in the Lean model.

### What is tested

1. **Point cases** (20 cases): specific strike/price pairs covering ATM, ITM, OTM,
   zero strike, zero price, small values, and large values.
2. **Non-negativity sweep** (162 cases): `payoff(type, K, S) ≥ 0` for all type/K/S
   combinations, matching `theorem payoff_nonneg`.
3. **Put-call parity sweep** (64 cases): `call(K,S) − put(K,S) = S − K`,
   matching `theorem put_call_parity`.
4. **Monotonicity sweep** (48 cases): call non-decreasing and put non-increasing in S,
   matching `theorem call_mono` and `theorem put_antimono`.
5. **Symmetry sweep** (49 cases): `call(K,S) = put(S,K)`,
   matching `theorem call_put_symmetry`.
6. **Convexity sweep** (480 cases): `payoff(K, t·S₁+(1−t)·S₂) ≤ t·payoff(K,S₁)+(1−t)·payoff(K,S₂)`,
   matching `theorem call_convex` and `theorem put_convex`.

### What is NOT tested

- The C++ class hierarchy (Payoff / TypePayoff / StrikedTypePayoff / visitor pattern)
- Floating-point edge cases (NaN, Inf, denormals) — the Lean model uses ℝ
- Error handling (unknown option type throws in C++)

## Build and Run

```bash
g++ -std=c++17 -O2 -o test_plainvanillapayoff test_plainvanillapayoff.cpp
./test_plainvanillapayoff
```

## Correspondence to Lean Theorems

| C++ Test | Lean Theorem | Property |
|----------|-------------|----------|
| Point cases | `call_atm`, `put_atm`, `call_itm`, `put_itm`, `call_otm`, `put_otm` | Formula correctness |
| Non-negativity sweep | `payoff_nonneg` | `payoff(type, K, S) ≥ 0` |
| Put-call parity sweep | `put_call_parity` | `call(S) − put(S) = S − K` |
| Monotonicity sweep | `call_mono`, `put_antimono` | Monotonicity in S |
| Symmetry sweep | `call_put_symmetry` | `call(K,S) = put(S,K)` |
| Convexity sweep | `call_convex`, `put_convex` | Convex in S |

## Source Provenance

The C++ logic in `test_plainvanillapayoff.cpp` is a direct copy of the formulas from
`ql/instruments/payoffs.cpp` lines 91–99. The Lean model in
`formal-verification/lean/FVSquad/PlainVanillaPayoff.lean` models the same formulas.
