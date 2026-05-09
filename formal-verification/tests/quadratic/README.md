# Quadratic Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## What This Tests

Verifies that the C++ `quadratic` class (`ql/math/quadratic.hpp/cpp`) behaves
identically to the Lean 4 model (`FVSquad.Quadratic`).

## Proved Properties Tested

| Test | Lean Theorem |
|------|-------------|
| eval at 0 | `eval_zero` |
| eval at 1 | `eval_one` |
| Horner form | `eval_eq_horner` |
| Turning point | `formalDeriv_at_turningPoint_zero` |
| Value at turning point | `valueAtTurningPoint_formula` |
| Discriminant | definition |
| Roots are zeros | `eval_rootSmall_eq_zero`, `eval_rootLarge_eq_zero` |
| Vieta sum | `vieta_sum`, `sum_of_roots` |
| Vieta product | `vieta_product` |
| Double root | `double_root` |
| No real roots | `root_implies_discriminant_nonneg` (contrapositive) |
| Symmetry | `eval_sym` |

## Build & Run

```bash
g++ -std=c++17 -o test_quadratic test_quadratic.cpp
./test_quadratic
```

## Results

63 test cases, 63 passed, 0 failed.
