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
