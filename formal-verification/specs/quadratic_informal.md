# Informal Specification: Quadratic Formula

🔬 *Lean Squad — automated formal verification.*

## Source
- **Files**: `ql/math/quadratic.hpp`, `ql/math/quadratic.cpp`
- **Class**: `QuantLib::quadratic`

## Purpose
Represents a quadratic polynomial `f(x) = ax² + bx + c` and provides operations for
evaluation, finding the vertex (turning point), computing the discriminant, and solving
for real roots using the quadratic formula.

## Preconditions
- `a ≠ 0` (required for the polynomial to be quadratic)
- For `roots()`: discriminant ≥ 0 for real roots to exist

## Postconditions

### `operator()(x)` — Evaluation
- Returns `a*x² + b*x + c`
- Implementation uses Horner form: `x*(x*a + b) + c` (equivalent, fewer multiplications)

### `turningPoint()`
- Returns `-b / (2a)` — the x-coordinate of the vertex
- The formal derivative `2ax + b` equals zero at this point

### `valueAtTurningPoint()`
- Returns `f(turningPoint())` = `c - b²/(4a)`

### `discriminant()`
- Returns `b² - 4ac`
- Δ ≥ 0 ⟺ real roots exist
- Δ = 0 ⟹ double root at the turning point

### `roots(x, y)`
- Sets `x = (-b - √Δ) / (2a)` (smaller root)
- Sets `y = (-b + √Δ) / (2a)` (larger root)
- Returns `true` if Δ ≥ 0 (real roots found)
- Returns `false` if Δ < 0 (sets both to turning point)

## Invariants
- **Vieta's sum**: root₁ + root₂ = -b/a
- **Vieta's product**: root₁ × root₂ = c/a
- **Root correctness**: f(root₁) = f(root₂) = 0 when Δ ≥ 0
- **Completing the square**: f(x) = a·(x - tp)² + f(tp)

## Edge Cases
- `b = 0`: roots are symmetric about 0
- `c = 0`: one root is always 0
- `Δ = 0`: double root at turning point
- Large coefficients: potential overflow in `b² - 4ac`

## Open Questions
- No validation of `a ≠ 0` at runtime — constructor allows any values
- Horner evaluation vs standard form: numerically equivalent but potentially different
  rounding behavior with floating-point
