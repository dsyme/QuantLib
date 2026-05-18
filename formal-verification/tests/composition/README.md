# Composition Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Overview

Validates the algebraic properties proved in `FVSquad.Composition` against
the intended QuantLib semantics implemented in Python (mirroring C++ behaviour).

## Running

```bash
python3 formal-verification/tests/composition/test_correspondence.py
```

## Coverage

- **52,904 test cases** covering all 28 theorems in Composition.lean
- Day count: additivity, antisymmetry, self, monotonicity, translation (exhaustive over small ranges)
- Payoff: non-negativity, put-call parity, monotonicity, ATM, OTM, ITM
- Discounting: identity, zero, associativity, parity preservation, non-negativity, monotonicity
- Compounding: zero days/rate, linearity, rate/time monotonicity
