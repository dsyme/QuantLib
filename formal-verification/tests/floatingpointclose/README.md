# Correspondence Tests: FloatingPointClose

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

These tests validate that the Lean 4 formal model (`FVSquad.FloatingPointClose`) corresponds
to the C++ implementation (`ql/math/comparison.hpp`).

## Approach (Route B — Executable Correspondence)

Since QuantLib is a C++ codebase (Aeneas not applicable), we use Route B:
a standalone C++ test harness that reimplements the minimal close/close_enough logic
and verifies it against the same properties proved in the Lean model.

### What is tested

1. **Reflexivity** (110 cases): `close(x,x,ε)` and `close_enough(x,x,ε)` for all x and ε≥0,
   matching `theorem close_refl` and `theorem close_enough_refl`.
2. **Symmetry** (1210 cases): `close(x,y,ε) ↔ close(y,x,ε)`,
   matching `theorem close_symm` and `theorem close_enough_symm`.
3. **Implication** (605 cases): `close(x,y,ε) → close_enough(x,y,ε)`,
   matching `theorem close_implies_close_enough`.
4. **Zero tolerance** (~160 cases): `close(x,y,0) ↔ (x=y)` for non-zero x,y,
   matching `theorem close_zero_tol`.
5. **Monotonicity in tolerance** (~968 cases): larger ε preserves closeness,
   matching `theorem close_mono_tol`.
6. **Strictly weaker** (2 cases): witness that close_enough is strictly weaker than close,
   matching `theorem close_enough_strictly_weaker`.
7. **Non-transitivity** (3 cases): witness that close is not transitive,
   matching `theorem close_not_transitive`.

### What is NOT tested

- IEEE 754 special values (NaN, ±∞) — the Lean model uses ℚ
- The `x == y` short-circuit (bitwise equality) — Lean model doesn't include this
- Machine epsilon scaling (`n * QL_EPSILON`)
- The strict `<` vs `≤` distinction for the zero case

## Build and Run

```bash
g++ -std=c++17 -O2 -o test_floatingpointclose test_floatingpointclose.cpp
./test_floatingpointclose
```

## Correspondence to Lean Theorems

| C++ Test | Lean Theorem | Property |
|----------|-------------|----------|
| Reflexivity | `close_refl`, `close_enough_refl` | `close(x,x,ε)` for ε≥0 |
| Symmetry | `close_symm`, `close_enough_symm` | `close(x,y,ε) ↔ close(y,x,ε)` |
| Implication | `close_implies_close_enough` | `close → close_enough` |
| Zero tolerance | `close_zero_tol`, `close_enough_zero_tol` | `close(x,y,0) ↔ x=y` |
| Mono tolerance | `close_mono_tol`, `close_enough_mono_tol` | Larger ε preserves closeness |
| Strictly weaker | `close_enough_strictly_weaker` | ∃ x,y,ε: ce ∧ ¬c |
| Non-transitive | `close_not_transitive` | ∃ x,y,z: c(x,y) ∧ c(y,z) ∧ ¬c(x,z) |

## Source Provenance

The C++ logic in `test_floatingpointclose.cpp` is a direct copy of the formulas from
`ql/math/comparison.hpp`. The Lean model uses ℚ instead of IEEE 754 doubles.
