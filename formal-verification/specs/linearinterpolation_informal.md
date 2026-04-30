# Informal Specification: LinearInterpolation

🔬 *Lean Squad — automated formal verification.*

## Purpose

Linear interpolation between discrete data points `(x₀, y₀), (x₁, y₁), ..., (xₙ₋₁, yₙ₋₁)`.
Given sorted x-values and corresponding y-values, compute `f(x)` for any `x` in range by
linearly interpolating between the two surrounding knot points.

## Source

- **File**: `ql/math/interpolations/linearinterpolation.hpp`
- **Class**: `LinearInterpolationImpl<I1, I2>`
- **Key methods**: `value(x)`, `derivative(x)`, `secondDerivative(x)`, `primitive(x)`

## Preconditions

- x-values are sorted in strictly increasing order: `x₀ < x₁ < ... < xₙ₋₁`
- At least 2 points (`requiredPoints = 2`)
- Query `x` is within `[x₀, xₙ₋₁]` (behaviour outside is implementation-defined via `locate`)

## Core Formulas

### Slopes

For each segment `i` (0-indexed, `0 ≤ i < n-1`):
```
s[i] = (y[i+1] - y[i]) / (x[i+1] - x[i])
```

### Value (interpolation)

Given `x` in segment `i` (i.e., `x[i] ≤ x < x[i+1]`):
```
value(x) = y[i] + (x - x[i]) * s[i]
```

### Derivative

```
derivative(x) = s[i]   (piecewise constant)
```

### Second Derivative

```
secondDerivative(x) = 0   (always)
```

### Primitive (antiderivative)

```
primitive(x) = primitiveConst[i] + (x - x[i]) * y[i] + 0.5 * (x - x[i])² * s[i]
```
where `primitiveConst[0] = 0` and
```
primitiveConst[i] = primitiveConst[i-1] + dx * (y[i-1] + 0.5 * dx * s[i-1])
```
with `dx = x[i] - x[i-1]`.

## Postconditions / Key Properties

1. **Knot interpolation**: `value(x[i]) = y[i]` for all knot points
2. **Continuity**: `value` is continuous on `[x₀, xₙ₋₁]`
3. **Linearity between knots**: within any segment, `value` is affine in `x`
4. **Monotonicity preservation**: if `y` is non-decreasing and `x` is sorted, then `value` is non-decreasing
5. **Derivative = slope**: `derivative(x) = s[i]` on segment `i`
6. **Second derivative = 0**: always
7. **Primitive correctness**: `d/dx(primitive(x)) = value(x)`
8. **Primitive continuity**: `primitive` is continuous across knot boundaries
9. **Bounded output**: `min(y) ≤ value(x) ≤ max(y)` for all x in domain (when monotone)

## Edge Cases

- **Two points**: single linear segment, `value` is globally affine
- **Constant function**: all `y[i]` equal → `value(x) = y[0]`, `derivative = 0`
- **Query at knot**: must return exact `y[i]` (no floating-point drift)
- **Adjacent equal x-values**: undefined (precondition violation — division by zero in slope)

## Invariants

- `s` has length `n-1`
- `primitiveConst` has length `n`
- `primitiveConst[0] = 0`

## Open Questions

- Behaviour when `x` is outside `[x₀, xₙ₋₁]` depends on `locate()` — likely flat extrapolation or nearest segment. Not modelled here.
- The `locate` function's exact semantics (binary search with clamping) affects boundary behaviour.
