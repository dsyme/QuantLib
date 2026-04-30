# LinearInterpolation Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Overview

This directory contains executable correspondence tests that validate
the Lean 4 model in `formal-verification/lean/FVSquad/LinearInterpolation.lean`
agrees with QuantLib's `LinearInterpolation` implementation.

## Approach (Route B)

Since the codebase is C++ (not Rust), we use Route B: a Python reference
implementation that mirrors the exact semantics of both the Lean model
and the C++ source, run on shared test fixtures.

The Python implementation in `run_tests.py` computes:
- `slope(xs, ys, i)` — slope of segment i
- `value(xs, ys, i, x)` — interpolated value at x in segment i
- `derivative(xs, ys, i)` — derivative (equals slope)
- `second_derivative()` — always 0

These match the Lean definitions exactly (using rationals in Lean, floats
in Python — acceptable since all test cases use exact rational values).

## Test Cases

`test_cases.json` contains 12 test cases covering:
- Knot interpolation (value at knot points)
- Midpoint and quarter-point evaluation
- Negative slopes
- Constant functions (zero slope)
- Steep slopes
- Non-uniform x-spacing
- Negative domain values
- Large values

## Running

```bash
python3 formal-verification/tests/linearinterpolation/run_tests.py
```

Expected output: `12/12 test cases passed.`

## What is validated

- `value(xs, ys, i, x)` correspondence for all test cases
- `derivative(xs, ys, i)` correspondence
- `secondDerivative` is always zero

## What is NOT validated

- Segment location (`locate` function) — we assume correct segment index
- Floating-point rounding (Lean uses exact rationals)
- Out-of-range extrapolation behaviour
- Performance characteristics
