# Informal Specification: Lagrange Interpolation (Barycentric Form)

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Source

- **File**: `ql/math/interpolations/lagrangeinterpolation.hpp`
- **Reference**: Berrut & Trefethen, "Barycentric Lagrange interpolation", SIAM Review 46(3):501–517, 2004.

## Purpose

Computes the unique polynomial of degree ≤ n−1 that passes through n given data points (x_i, y_i), using the **second barycentric form**:

```
p(x) = [ Σ_i λ_i/(x − x_i) · y_i ] / [ Σ_i λ_i/(x − x_i) ]
```

where `λ_i = 1 / Π_{j≠i} c·(x_i − x_j)` are the barycentric weights (scaled by a constant `c = 4/(x_{n-1} − x_0)` for numerical stability).

## Preconditions

1. The x-values must all be **distinct** (no duplicates).
2. At least one data point must be provided (n ≥ 1).
3. The x-values array and y-values array must have the same length.

## Postconditions

1. **Interpolation property**: For every node `x_i` in the data set, `p(x_i) = y_i`.
2. **Uniqueness**: The result agrees with the unique interpolating polynomial of degree ≤ n−1.
3. **Exactness on polynomials**: If the data points lie on a polynomial of degree ≤ n−1, then `p(x) = q(x)` for all x (not just at nodes).
4. **Linearity in y**: The interpolant is a linear operator on y-values. That is, `interp(α·y + β·z, x) = α·interp(y, x) + β·interp(z, x)`.
5. **Continuity**: The interpolant `p(x)` is continuous everywhere (including at nodes, despite the apparent singularity in the barycentric formula).

## Invariants

- The barycentric weights `λ_i` depend only on the x-values, not on y.
- The scaling constant `c = 4/(x_{n-1} − x_0)` prevents overflow/underflow in the weight products but does not affect the mathematical result (it cancels in the ratio).
- `update()` must be called after construction to compute weights.

## Edge Cases

| Condition | Expected behaviour |
|-----------|-------------------|
| n = 1 (single point) | Returns y_0 for all x |
| x = x_i exactly | Returns y_i directly (guards against division by zero) |
| x very close to x_i (within 10·ε·|x|) | Returns y_i via tolerance check |
| Duplicate x-values | Undefined behaviour (QL_EXTRA_SAFETY_CHECKS asserts) |
| Extremely large n | Numerically unstable for equidistant points (Runge phenomenon — but algorithm is correct) |

## Key Properties for Formal Verification

1. **Interpolation at nodes**: `∀ i, value(y, x_i) = y_i`
2. **Weight correctness**: `λ_i = 1 / Π_{j≠i} c·(x_i − x_j)` and the sum `Σ λ_i/(x − x_i)` is non-zero for x ≠ x_i.
3. **Partition of unity**: If all y_i = 1, then p(x) = 1 for all x (follows from the formula structure).
4. **Linearity**: `value(α·y + β·z, x) = α·value(y, x) + β·value(z, x)`
5. **Derivative formula correctness**: The derivative formula uses the quotient rule on the barycentric form.

## Examples

| x-nodes | y-values | Query x | Expected result |
|---------|----------|---------|-----------------|
| [0, 1] | [0, 1] | 0.5 | 0.5 (linear) |
| [0, 1] | [3, 3] | 0.5 | 3.0 (constant) |
| [0, 1, 2] | [0, 1, 4] | 1.5 | 2.25 (quadratic x²) |
| [-1, 0, 1] | [1, 0, 1] | 0.5 | 0.25 (x²) |

## Inferred Intent

The barycentric form is chosen for O(n) evaluation (after O(n²) precomputation of weights), numerical stability compared to the classical Lagrange form, and the ability to update y-values without recomputing weights (`updatedValue`). The scaling constant c is a classical trick to keep weights near unit magnitude.

## Open Questions

1. **Tolerance handling**: The `10*QL_EPSILON*|x|` tolerance for node proximity — is this the optimal threshold? Could it produce incorrect results for nodes spaced closer than this?
2. **Weight overflow**: For large n with equidistant points, barycentric weights grow factorially. The scaling by c mitigates but doesn't eliminate this. Is there a practical n-limit?
3. **Derivative at nodes**: The derivative formula uses a special case at nodes — is this formula equivalent to L'Hôpital's limit of the general formula?
