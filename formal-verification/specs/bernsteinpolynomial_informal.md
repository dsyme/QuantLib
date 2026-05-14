# Informal Specification: BernsteinPolynomial

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `BernsteinPolynomial::get(i, n, x)` function computes the i-th Bernstein basis polynomial of degree n evaluated at x:

$$B_{i,n}(x) = \binom{n}{i} x^i (1-x)^{n-i}$$

Bernstein polynomials form a basis for the space of polynomials of degree ≤ n on [0, 1]. They are used in QuantLib for curve fitting and interpolation (e.g., Bézier curves for yield curve construction).

## Preconditions

- `0 ≤ i ≤ n` (index within valid range)
- `n ≥ 0` (non-negative degree)
- `x` is a real number (typically in [0, 1] for standard use, but computable for any x)

## Postconditions

The returned value equals `C(n, i) * x^i * (1 - x)^(n - i)` where `C(n, i) = n! / (i! * (n-i)!)`.

## Invariants / Key Properties

### 1. Partition of Unity
For any x ∈ [0, 1]:
$$\sum_{i=0}^{n} B_{i,n}(x) = 1$$

This is the most important property — it follows from the binomial theorem applied to `(x + (1-x))^n = 1^n = 1`.

### 2. Non-negativity on [0, 1]
For x ∈ [0, 1] and 0 ≤ i ≤ n:
$$B_{i,n}(x) \geq 0$$

Since the binomial coefficient is positive, and `x^i ≥ 0`, `(1-x)^(n-i) ≥ 0` on [0, 1].

### 3. Boundary Values
- `B_{0,n}(0) = 1` (only the first polynomial is nonzero at x=0)
- `B_{n,n}(1) = 1` (only the last polynomial is nonzero at x=1)
- `B_{i,n}(0) = 0` for i > 0
- `B_{i,n}(1) = 0` for i < n

### 4. Symmetry
$$B_{i,n}(x) = B_{n-i,n}(1-x)$$

### 5. Maximum on [0, 1]
Each `B_{i,n}` attains its maximum at `x = i/n` (for n ≥ 1).

### 6. Recursion (de Casteljau)
$$B_{i,n}(x) = (1-x) \cdot B_{i,n-1}(x) + x \cdot B_{i-1,n-1}(x)$$

with base case `B_{0,0}(x) = 1`.

### 7. Degree Elevation
$$B_{i,n}(x) = \frac{n+1-i}{n+1} B_{i,n+1}(x) + \frac{i+1}{n+1} B_{i+1,n+1}(x)$$

### 8. Derivative
$$\frac{d}{dx} B_{i,n}(x) = n \left[ B_{i-1,n-1}(x) - B_{i,n-1}(x) \right]$$

## Edge Cases

- `B_{0,0}(x) = 1` for all x (the constant polynomial 1)
- `n = 0, i = 0`: always returns 1.0 regardless of x
- `x = 0`: only `B_{0,n}(0) = 1`, all others are 0
- `x = 1`: only `B_{n,n}(1) = 1`, all others are 0
- `x` outside [0, 1]: the polynomial is still well-defined but may be negative

## Examples

| i | n | x   | Expected B_{i,n}(x) |
|---|---|-----|---------------------|
| 0 | 0 | 0.5 | 1.0                 |
| 0 | 1 | 0.5 | 0.5                 |
| 1 | 1 | 0.5 | 0.5                 |
| 0 | 2 | 0.5 | 0.25                |
| 1 | 2 | 0.5 | 0.5                 |
| 2 | 2 | 0.5 | 0.25                |
| 0 | 3 | 0.0 | 1.0                 |
| 3 | 3 | 1.0 | 1.0                 |
| 1 | 3 | 0.0 | 0.0                 |
| 0 | 2 | 1.0 | 0.0                 |

## Inferred Intent

The implementation uses `Factorial::get()` to compute the binomial coefficient, then multiplies by the power terms. This is the straightforward definition — no numerically stable alternative (like the de Casteljau recursion) is used. The function is intended for relatively small `n` where factorial overflow is not a concern (QuantLib's `Factorial` class supports up to n=170 using lookup tables).

## Open Questions

1. **No bounds checking**: what happens if `i > n`? The code computes `Factorial::get(n-i)` which would underflow for unsigned Natural type. Should the spec require `i ≤ n` as a precondition, or should it specify error behaviour?
2. **Floating-point accuracy**: for large n, the factorial-based computation loses precision. Should we verify against a more stable recursive formulation?
3. **Usage scope**: is this function used elsewhere in QuantLib beyond the B-spline / Bézier interpolation context? Understanding callers would help prioritise which properties matter most.

## Relationship to Other Targets

- **Factorial** (already verified): `BernsteinPolynomial::get` directly calls `Factorial::get`, so the factorial correctness proof provides a foundation for this target.
- **LinearInterpolation** (already verified): Bernstein polynomials generalise linear interpolation (`B_{i,1}` gives the linear basis functions).
