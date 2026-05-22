# Informal Specification: Copulas

🔬 *Lean Squad — automated formal verification.*

## Purpose

This module implements bivariate copula functions used throughout QuantLib for modelling dependence structures between random variables in credit derivatives pricing, portfolio risk, and multi-asset options. A copula C : [0,1]² → [0,1] is a joint CDF of uniform marginals.

## Source

- **Directory**: `ql/math/copulas/`
- **Key files**: `independentcopula.cpp`, `mincopula.cpp`, `maxcopula.cpp`, `claytoncopula.cpp`, `frankcopula.cpp`, `gumbelcopula.cpp`, `farliegumbelmorgensterncopula.cpp`, `marshallolkincopula.cpp`, `alimikhailhaqcopula.cpp`

---

## Functions

### IndependentCopula (Π copula)

```
C(x, y) = x · y
```

Models independence. Parameter-free.

### MaxCopula (Fréchet upper bound, M copula)

```
C(x, y) = min(x, y)
```

Models perfect positive dependence (comonotonicity). Parameter-free.

### MinCopula (Fréchet lower bound, W copula)

```
C(x, y) = max(x + y − 1, 0)
```

Models perfect negative dependence (countermonotonicity). Parameter-free.

### ClaytonCopula

```
C(x, y) = max((x^(−θ) + y^(−θ) − 1)^(−1/θ), 0)
```

- Parameter: θ ∈ [−1, ∞) \ {0}
- θ → 0⁺: approaches independence
- θ → ∞: approaches upper Fréchet bound (comonotonicity)
- θ = −1: lower Fréchet bound (countermonotonicity)
- Exhibits lower tail dependence

### FrankCopula

```
C(x, y) = −(1/θ) · ln(1 + (e^(−θx) − 1)(e^(−θy) − 1) / (e^(−θ) − 1))
```

- Parameter: θ ∈ ℝ \ {0}
- θ → 0: approaches independence
- θ → +∞: approaches upper Fréchet bound
- θ → −∞: approaches lower Fréchet bound
- No tail dependence (symmetric)

### GumbelCopula

```
C(x, y) = exp(−((−ln x)^θ + (−ln y)^θ)^(1/θ))
```

- Parameter: θ ∈ [1, ∞)
- θ = 1: independence
- θ → ∞: upper Fréchet bound
- Exhibits upper tail dependence

### FarlieGumbelMorgensternCopula (FGM)

```
C(x, y) = x · y + θ · x · y · (1 − x) · (1 − y)
```

- Parameter: θ ∈ [−1, 1]
- θ = 0: independence
- Limited dependence range (Kendall's τ ∈ [−2/9, 2/9])

### AliMikhailHaqCopula

```
C(x, y) = x · y / (1 − θ · (1 − x) · (1 − y))
```

- Parameter: θ ∈ [−1, 1]
- θ = 0: independence

### MarshallOlkinCopula

```
C(x, y) = min(y · x^a₁, x · y^a₂)
```

- Parameters: a₁, a₂ ∈ [0, 1]
- a₁ = a₂ = 1: independence (min(xy, xy) = xy)
- a₁ = a₂ = 0: upper Fréchet bound (min(y, x) = min(x,y))
- Not absolutely continuous — has a singular component

---

## Preconditions

All copulas require:
- `x ∈ [0, 1]`
- `y ∈ [0, 1]`

Parameter constraints:
- Clayton: θ ≥ −1, θ ≠ 0
- Frank: θ ≠ 0
- Gumbel: θ ≥ 1
- FGM: θ ∈ [−1, 1]
- Ali-Mikhail-Haq: θ ∈ [−1, 1]
- Marshall-Olkin: a₁ ∈ [0, 1], a₂ ∈ [0, 1]

---

## Postconditions / Key Properties

Every valid copula C : [0,1]² → [0,1] must satisfy:

### 1. Grounding (boundary at zero)
- `C(x, 0) = 0` for all x ∈ [0,1]
- `C(0, y) = 0` for all y ∈ [0,1]

### 2. Boundary (uniform marginals)
- `C(x, 1) = x` for all x ∈ [0,1]
- `C(1, y) = y` for all y ∈ [0,1]

### 3. Fréchet–Hoeffding bounds
- `max(x + y − 1, 0) ≤ C(x, y) ≤ min(x, y)` for all x, y ∈ [0,1]

### 4. 2-increasing (quasi-monotonicity)
For all 0 ≤ x₁ ≤ x₂ ≤ 1, 0 ≤ y₁ ≤ y₂ ≤ 1:
- `C(x₂, y₂) − C(x₂, y₁) − C(x₁, y₂) + C(x₁, y₁) ≥ 0`

### 5. Monotonicity
- C is non-decreasing in each argument

### 6. Symmetry (for symmetric copulas)
- Independent: `C(x, y) = C(y, x)` ✓
- Clayton: `C(x, y) = C(y, x)` ✓
- Frank: `C(x, y) = C(y, x)` ✓
- Gumbel: `C(x, y) = C(y, x)` ✓
- FGM: `C(x, y) = C(y, x)` ✓
- Ali-Mikhail-Haq: `C(x, y) = C(y, x)` ✓
- Marshall-Olkin: NOT symmetric unless a₁ = a₂

### 7. Limit cases (parametric families)
- Clayton(θ → 0⁺) → Π (independence)
- Frank(θ → 0) → Π
- Gumbel(θ = 1) = Π exactly
- FGM(θ = 0) = Π exactly
- AMH(θ = 0) = Π exactly

---

## Invariants

- Output always in [0, 1] for valid inputs
- All copulas are Lipschitz continuous with constant 1 in each variable
- C(x, y) ≤ x and C(x, y) ≤ y always

---

## Edge Cases

- `C(0, 0) = 0` (all copulas)
- `C(1, 1) = 1` (all copulas)
- `C(x, x)` for the diagonal: ranges from `max(2x−1, 0)` to `x`
- Clayton at boundary: when x or y = 0, the power `x^(−θ)` → ∞ for θ > 0, but the implementation uses `max(..., 0)` to handle this
- Gumbel: when x = 0, `−ln(0) = ∞`, so `C(0, y) = exp(−∞) = 0`
- Frank: as θ → 0, the formula is numerically unstable (0/0 form)

---

## Examples

| Copula | x | y | θ | C(x,y) |
|--------|---|---|---|--------|
| Independent | 0.5 | 0.5 | — | 0.25 |
| Max | 0.3 | 0.7 | — | 0.3 |
| Min | 0.3 | 0.7 | — | 0.0 |
| Clayton | 0.5 | 0.5 | 2 | (2·0.5^(−2) − 1)^(−1/2) = (2·4−1)^(−0.5) = 7^(−0.5) ≈ 0.378 |
| FGM | 0.5 | 0.5 | 1 | 0.25 + 1·0.25·0.25 = 0.3125 |
| AMH | 0.5 | 0.5 | 0.5 | 0.25/(1−0.5·0.25) = 0.25/0.875 ≈ 0.286 |

---

## Inferred Intent

The copula module provides building blocks for multivariate dependence modelling in credit and equity derivatives. The variety of families (Archimedean: Clayton, Frank, Gumbel; extreme-value: Gumbel, Galambos; elliptical: Gaussian; other: FGM, AMH, Marshall-Olkin, Plackett) gives users flexibility to model different tail dependence structures.

---

## Open Questions

1. **MinCopula naming**: The code names it "MinCopula" but it computes `max(x+y−1, 0)` (the Fréchet *lower* bound W). The "Max" copula computes `min(x, y)` (the Fréchet *upper* bound M). The naming is from the perspective of the Fréchet bounds (W = min dependence, M = max dependence), not the mathematical operation. This could be confusing — consider documenting this choice.
2. **Clayton at θ < 0**: For θ ∈ (−1, 0), the Clayton formula `(x^(−θ) + y^(−θ) − 1)^(−1/θ)` can yield values outside [0,1] at the boundary, which is why `max(..., 0)` is needed. Is this correct for all (x,y) ∈ [0,1]²?
3. **No tests**: There appear to be no dedicated unit tests for copulas in the test suite. Formal verification would fill this gap.

---

## FV Strategy

**High-value properties to verify** (prioritised):
1. **Grounding and boundary conditions** — decidable for all parameter-free copulas (Independent, Max, Min); algebraic simplification for parametric ones
2. **Fréchet–Hoeffding bounds** — proves every copula's output is valid; algebraically tractable
3. **Symmetry** — straightforward algebraic proof for symmetric copulas
4. **2-increasing property** — the key correctness property; harder but approachable algebraically for FGM, AMH, and Independent

**Specification size**: ~100–150 lines for definitions + boundary/grounding/bounds theorems for the 3 parameter-free copulas and 2–3 parametric ones.

**Proof tractability**: 
- Parameter-free copulas (Independent, Max, Min): all properties provable by `norm_num`, `omega`, `simp`, `linarith`
- FGM, AMH: algebraic, should yield to `ring` + `nlinarith` / `polyrith`
- Clayton, Gumbel: involve real powers — harder; may need `sorry` for some properties

**Lean 4 approach**: Model on ℝ with explicit hypotheses `0 ≤ x`, `x ≤ 1`, etc. Use `Real.rpow` for Clayton/Gumbel power operations if needed.
