# Informal Specification: Normal Distribution

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `normaldistribution.hpp/cpp` module provides three related classes:

1. **NormalDistribution** — evaluates the Gaussian PDF: `f(x) = (1/(σ√(2π))) · exp(-(x-μ)²/(2σ²))`
2. **CumulativeNormalDistribution** — evaluates the Gaussian CDF: `Φ(x) = ∫_{-∞}^{x} f(t) dt`
3. **InverseCumulativeNormal** — evaluates Φ⁻¹(p) using Acklam's rational approximation

## Preconditions

- `NormalDistribution(μ, σ)`: `σ > 0`
- `CumulativeNormalDistribution(μ, σ)`: `σ > 0`
- `InverseCumulativeNormal(μ, σ)`: `σ > 0`
- `InverseCumulativeNormal::operator()(x)`: `0 < x < 1`

## Postconditions

### NormalDistribution::operator()(x)
- Returns `f(x) = (1/(σ√(2π))) · exp(-(x-μ)²/(2σ²))`
- Result is always non-negative: `f(x) ≥ 0`
- Result is maximised at `x = μ`: `f(μ) = 1/(σ√(2π))`
- Symmetric about the mean: `f(μ + d) = f(μ - d)` for all `d`

### NormalDistribution::derivative(x)
- Returns `f'(x) = -(x-μ)/σ² · f(x)`
- `f'(μ) = 0` (peak has zero derivative)
- `f'(x) > 0` for `x < μ`, `f'(x) < 0` for `x > μ`

### CumulativeNormalDistribution::operator()(x)
- Returns an approximation to `Φ(x)` via the error function: `Φ(x) = 0.5 · (1 + erf((x-μ)/(σ√2)))`
- `0 ≤ Φ(x) ≤ 1` for all `x`
- `Φ(μ) = 0.5`
- Monotonically non-decreasing: `x₁ ≤ x₂ ⟹ Φ(x₁) ≤ Φ(x₂)`
- `lim_{x→-∞} Φ(x) = 0`, `lim_{x→+∞} Φ(x) = 1`
- `Φ(x) + Φ(2μ - x) = 1` (symmetry about mean)

### CumulativeNormalDistribution::derivative(x)
- Returns `f(x)` (the PDF), since `Φ'(x) = f(x)`

### InverseCumulativeNormal::operator()(p)
- Returns `μ + σ · Φ⁻¹_standard(p)`
- Round-trip: `Φ(Φ⁻¹(p)) ≈ p` for `p ∈ (0, 1)` (within ~1.15e-9 relative error)
- Monotonically increasing: `p₁ < p₂ ⟹ Φ⁻¹(p₁) < Φ⁻¹(p₂)`
- `Φ⁻¹(0.5) = μ`
- Symmetry: `Φ⁻¹(1-p) = 2μ - Φ⁻¹(p)`

## Invariants

- The `normalizationFactor_` is always `1/(σ√(2π))` (positive)
- The `denominator_` is always `2σ²` (positive)
- `InverseCumulativeNormal::standard_value` computes the standard (μ=0, σ=1) case

## Edge Cases

- `σ` approaching zero: not handled (precondition violation)
- `InverseCumulativeNormal(0)` and `InverseCumulativeNormal(1)`: tail approximation gives ±∞ in the limit
- Very small CDF values (< 1e-8): asymptotic expansion is used
- Tail values in InverseCumulativeNormal use a separate rational approximation (coefficients `c1_`–`c6_`, `d1_`–`d4_`)

## Examples

For standard normal (μ=0, σ=1):
- `f(0) = 1/√(2π) ≈ 0.398942`
- `Φ(0) = 0.5`
- `Φ(1) ≈ 0.841345`
- `Φ(-1) ≈ 0.158655`
- `Φ⁻¹(0.5) = 0`
- `Φ⁻¹(0.975) ≈ 1.96`
- `Φ⁻¹(0.025) ≈ -1.96`

## Inferred Intent

The three classes form a coherent unit: `NormalDistribution` is the density, `CumulativeNormalDistribution` is its integral, and `InverseCumulativeNormal` is the inverse of the integral. Together they support option pricing (Black-Scholes), risk calculations (VaR), and random variate generation from uniform distributions.

The implementation prioritises:
1. Speed (inlined methods, branch-free central region)
2. Accuracy (asymptotic expansions in tails, optional Halley refinement)
3. Low-discrepancy compatibility (InverseCumulativeNormal preserves sequence properties)

## FV-Amenable Properties (Recommended for Lean 4)

The following abstract/mathematical properties can be verified without modelling floating-point:

1. **PDF non-negativity**: `f(x) ≥ 0` for all `x` (over ℝ)
2. **PDF symmetry**: `f(μ + d) = f(μ - d)` (over ℝ)
3. **PDF peak**: `f(μ) ≥ f(x)` for all `x` (over ℝ)
4. **CDF range**: `0 ≤ Φ(x) ≤ 1` (conceptual — model as bounded)
5. **CDF monotonicity**: `x₁ ≤ x₂ ⟹ Φ(x₁) ≤ Φ(x₂)` (over ℝ, using Mathlib's `MeasureTheory`)
6. **CDF-PDF relationship**: `Φ'(x) = f(x)` (derivative relationship)
7. **Inverse round-trip**: `Φ(Φ⁻¹(p)) = p` (exact over ℝ, not accounting for approximation)
8. **Inverse monotonicity**: `p₁ < p₂ ⟹ Φ⁻¹(p₁) < Φ⁻¹(p₂)`
9. **Symmetry of inverse**: `Φ⁻¹(1-p) = -Φ⁻¹(p)` (standard case)
10. **Peak derivative zero**: `f'(μ) = 0`

Many of these are available directly from Mathlib's `MeasureTheory.Measure.gaussian` or `Mathlib.Analysis.SpecialFunctions.Gaussian`.

## Open Questions

- Should we model the Acklam approximation coefficients and verify approximation error bounds? This would be complex but high-value.
- Should we verify the asymptotic tail expansion in `CumulativeNormalDistribution::operator()`?
- The `MoroInverseCumulativeNormal` class is an alternative implementation — should we verify equivalence or just one?
- How to handle the distinction between exact mathematical properties (over ℝ) and numerical accuracy claims?
