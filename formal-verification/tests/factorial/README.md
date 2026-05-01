# Factorial Correspondence Tests

🔬 *Lean Squad — automated formal verification.*

## Overview

This directory contains correspondence tests validating that the Lean model
`FVSquad.Factorial` (which uses `Nat.factorial`) matches the QuantLib C++
implementation `Factorial::get(n)`.

## Route B: Executable Correspondence Tests

The QuantLib C++ implementation uses a precomputed lookup table for `n = 0..27`
and falls back to the gamma function for `n > 27`. Our Lean model captures the
mathematical specification (`Nat.factorial`), which computes exact integer values.

## Running

```bash
python3 formal-verification/tests/factorial/test_correspondence.py
```

## What's Tested

1. **Table correspondence** (28 cases): exact match between `math.factorial(n)`
   (equivalent to Lean's `Nat.factorial n`) and the QuantLib precomputed table
   values for `n = 0..27`.

2. **Property spot-checks**: verify key properties proved in Lean also hold
   empirically:
   - `factorial_pos`: `n! > 0` for all n
   - `factorial_succ`: `(n+1)! = (n+1) × n!`
   - `factorial_mono`: `n ≤ m → n! ≤ m!`
   - `factorial_even_div`: `2 | n!` for `n ≥ 2`

## Coverage

- **n = 0..27**: exact integer correspondence with QuantLib lookup table
- **n > 27**: not tested (QuantLib uses gamma function approximation with
  floating-point, which would require tolerance-based comparison)

## Correspondence Level

**Exact** for n = 0..27 (integer domain). The Lean model `Nat.factorial` and
the QuantLib `tabulated[]` array compute identical values.
