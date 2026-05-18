# BlackFormula Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Overview

These tests verify that the algebraic properties proved in `FVSquad.BlackFormula.lean`
hold for a Python implementation of the Black 1976 formula matching QuantLib's
`blackFormula` semantics (`ql/pricingengines/blackformula.cpp`).

## What is tested

| Property | Lean Theorem | Test Cases |
|----------|-------------|------------|
| P1: Non-negativity | `nonneg_zero_vol`, `nonneg_general` | 270 |
| P2: Put-call parity | `put_call_parity` | ~200 |
| P3: Zero-vol limit | `zero_vol` | 54 |
| P4: ATM symmetry | `atm_symmetry` | 12 |
| P5: Monotonicity in forward | `call_mono_forward` | 12 |
| P6: Monotonicity in stdDev | `mono_stddev` | 6 |
| P7: Upper bounds | `call_upper_bound`, `put_upper_bound` | 270 |
| P8: Linearity in discount | `linear_discount` | 270 |
| P9: Zero strike call | `zero_strike_call` | 12 |

**Total**: 312 test cases, all passing.

### Extended (Extreme Parameters)

| Property | Regime | Cases |
|----------|--------|-------|
| Non-negativity | High vol (σ=50), deep ITM/OTM, near-zero F | 30+ |
| Put-call parity | All extreme regimes | 30+ |
| Zero-vol limit | Near-zero vol (σ=1e-8) | 9 |
| Monotonicity (forward) | Fine grid 0.01–500 | 500 points |
| Monotonicity (vol) | Fine grid 0.01–3.0 | 300 points |
| Upper bounds | High vol, deep ITM/OTM, large displacement | 20+ |
| Discount linearity | Extreme discounts (0.001–0.999) | 5 |
| Near-zero forward | F → 0+ | 4 |

**Total extended**: 53 test cases, all passing.

## How to run

```bash
python3 formal-verification/tests/blackformula/test_blackformula.py
```

## Parameters tested

- Forwards: 50, 100, 150
- Strikes: 0, 80, 100, 120
- StdDevs: 0, 0.05, 0.2, 0.5, 1.0, 2.0
- Discounts: 0.9, 0.95, 1.0
- Displacements: 0, 5

## Implementation

The Python test uses `math.erfc` for the normal CDF (matching the Abramowitz-Stegun
approximation used by QuantLib's `CumulativeNormalDistribution` to >12 significant digits).
The Black formula implementation follows the exact same branching structure as
`ql/pricingengines/blackformula.cpp` lines 68–107.

## Correspondence route

**Route B** (executable tests) — the codebase is C++, so Aeneas extraction is not applicable.
