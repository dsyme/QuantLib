# Correspondence Tests: NormalDistribution

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

Validates that the Lean 4 model (`FVSquad.NormalDistribution`) corresponds to
the C++ implementation (`ql/math/distributions/normaldistribution.hpp/cpp`).

## Approach (Route B — Executable Correspondence)

Python reference implementations of the exact mathematical formulas from the
Lean model are tested against known values and property checks.

### What is tested

| Test | Cases | Property |
|------|-------|----------|
| PDF point values | 116 | `gaussianPDF` matches formula `(1/(σ√(2π)))·exp(-(x-μ)²/(2σ²))` |
| PDF symmetry | 140 | `f(μ+d) = f(μ-d)` for grid of μ, σ, d |
| PDF peak | 120 | `f(μ) ≥ f(x)` for all tested x |
| PDF non-negativity | 492 | `f(x) ≥ 0` across wide grid |
| CDF point values | 63 | `gaussianCDF` matches `0.5·(1+erf((x-μ)/(σ√2)))` |
| CDF at mean | 25 | `Φ(μ) = 0.5` |
| CDF symmetry | 63 | `Φ(2μ-x) + Φ(x) = 1` |
| PDF derivative sign | 63 | `f'(x) > 0` for x < μ, `= 0` at μ, `< 0` for x > μ |
| **Total** | **1082** | |

### How to run

```bash
python3 formal-verification/tests/normaldistribution/test_normaldistribution.py
```

### What is NOT tested

- The C++ asymptotic tail expansion for very small CDF values
- The Acklam rational approximation coefficients (InverseCumulativeNormal)
- Floating-point rounding behaviour
- The exp(-690) cutoff in the C++ PDF
