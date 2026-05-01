# Informal Specification: Black Formula (`blackFormula`)

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Purpose

The Black 1976 formula computes the price of a European call or put option on a
forward contract. It is the industry-standard pricing model for interest rate caps,
floors, swaptions, and commodity options. The QuantLib implementation also supports a
*displaced diffusion* variant where the forward and strike are shifted by a constant
displacement δ ≥ 0.

**Primary function**: `blackFormula(optionType, strike, forward, stdDev, discount, displacement)`

The formula is:

```
Call: D · [F'·Φ(d₁) − K'·Φ(d₂)]
Put:  D · [K'·Φ(−d₂) − F'·Φ(−d₁)]

where:
  F' = forward + displacement
  K' = strike + displacement
  d₁ = ln(F'/K') / σ + σ/2
  d₂ = d₁ − σ
  σ  = stdDev  (= volatility × √T)
  D  = discount factor
  Φ  = standard normal CDF
```

## Source Files

- **Header**: `ql/pricingengines/blackformula.hpp` (424 lines)
- **Implementation**: `ql/pricingengines/blackformula.cpp` (972 lines)
- **Tests**: `test-suite/blackformula.cpp`

## Scope for Formal Verification

We focus on the core `blackFormula` function and its key mathematical properties.
The implied-volatility solvers (`blackFormulaImpliedStdDev`, etc.) are secondary
targets — they compose `blackFormula` with root-finding and are harder to model.

### Functions in scope

| Function | Purpose | FV Priority |
|----------|---------|-------------|
| `blackFormula` | Option price via Black '76 | **Primary** |
| `blackFormulaForwardDerivative` | ∂price/∂forward (delta) | Secondary |
| `blackFormulaCashItmProbability` | Φ(±d₂), probability of cash ITM | Secondary |
| `blackFormulaAssetItmProbability` | Φ(±d₁), probability of asset ITM | Secondary |
| `blackFormulaStdDevDerivative` | Vega: ∂price/∂σ | Secondary |

### Functions out of scope (this phase)

- `blackFormulaImpliedStdDev` and variants (Newton solver, too complex for initial spec)
- `bachelierBlackFormula` (different model — Normal instead of Log-Normal)

## Preconditions

From the C++ code (`checkParameters` and inline `QL_REQUIRE`):

1. `displacement ≥ 0`
2. `strike + displacement ≥ 0`
3. `forward + displacement > 0`
4. `stdDev ≥ 0`
5. `discount > 0`

## Postconditions

### P1: Non-negativity
The option price is always non-negative:
```
blackFormula(type, K, F, σ, D, δ) ≥ 0
```
This is enforced by an `QL_ENSURE` in the code and is mathematically guaranteed by the formula.

### P2: Put-Call Parity
For the same strike, forward, stdDev, discount, and displacement:
```
Call(K, F, σ, D, δ) − Put(K, F, σ, D, δ) = D · (F − K)
```
This is the displaced-diffusion version of put-call parity. It follows from `Φ(d₁) − Φ(−d₁) = 1`
and `Φ(d₂) − Φ(−d₂) = 1` (since Φ(x) + Φ(−x) = 1).

### P3: Zero volatility limit
When `stdDev = 0`:
```
Call = D · max(F − K, 0)
Put  = D · max(K − F, 0)
```
This is the intrinsic value — the code handles this as a special case.

### P4: ATM symmetry
At-the-money (K = F, no displacement), with discount = 1:
```
Call(F, F, σ, 1, 0) = Put(F, F, σ, 1, 0)
```
Both equal `F · [Φ(σ/2) − Φ(−σ/2)]`. This follows from put-call parity (P2) since F − K = 0.

### P5: Monotonicity in forward
For a call, the price is non-decreasing in the forward rate:
```
F₁ ≤ F₂ ⟹ Call(K, F₁, σ, D, δ) ≤ Call(K, F₂, σ, D, δ)
```
For a put, non-increasing. This is because `blackFormulaForwardDerivative` for a call is `D · Φ(d₁) ≥ 0`.

### P6: Monotonicity in stdDev (vega non-negativity)
The option price is non-decreasing in volatility (stdDev):
```
σ₁ ≤ σ₂ ⟹ blackFormula(type, K, F, σ₁, D, δ) ≤ blackFormula(type, K, F, σ₂, D, δ)
```
This is because vega = `D · F' · φ(d₁) · √T ≥ 0` (where φ is the PDF).

### P7: Bounds
```
0 ≤ Call(K, F, σ, D, δ) ≤ D · F'
0 ≤ Put(K, F, σ, D, δ)  ≤ D · K'
```
where F' = F + δ, K' = K + δ.

### P8: Linearity in discount
```
blackFormula(type, K, F, σ, D, δ) = D · blackFormula(type, K, F, σ, 1, δ)
```
The discount factor is a simple multiplicative scalar.

### P9: Zero strike (call)
When `strike + displacement = 0` (which requires `displacement = 0` and `strike = 0`):
```
Call(0, F, σ, D, 0) = D · F
```
A zero-strike call is worth the discounted forward.

## Invariants

- The formula is a pure function of its arguments — no side effects or state.
- The function composes with `CumulativeNormalDistribution` (our already-verified NormalDistribution target).

## Edge Cases

| Case | Expected Behaviour |
|------|-------------------|
| `stdDev = 0` | Returns intrinsic value: `D · max(sign · (F − K), 0)` |
| `strike = 0, displacement = 0` | Call returns `D · F`; Put returns `0` |
| `forward = strike` (ATM) | Call = Put (by put-call parity with F = K) |
| `forward ≫ strike` (deep ITM call) | Approaches `D · (F − K)` |
| `forward ≪ strike` (deep OTM call) | Approaches `0` |
| Very large `stdDev` | Call → `D · F'`, Put → `D · K'` |

## Examples

Using no displacement (δ = 0) and discount = 1:

| Type | K | F | σ | Expected (approx) | Notes |
|------|---|---|---|-------------------|-------|
| Call | 100 | 100 | 0.20 | ≈ 7.97 | ATM |
| Put  | 100 | 100 | 0.20 | ≈ 7.97 | ATM (= Call by P4) |
| Call | 100 | 110 | 0.20 | ≈ 13.27 | ITM call |
| Put  | 100 | 110 | 0.20 | ≈ 3.27 | OTM put, = Call − 10 (P2) |
| Call | 100 | 100 | 0.00 | 0 | Zero vol ATM |
| Call | 100 | 105 | 0.00 | 5 | Zero vol ITM |

## Inferred Intent

1. The `displacement` parameter implements the *shifted lognormal* (displaced diffusion) model,
   which allows pricing when the underlying can take negative values (the shifted forward F + δ
   is always positive).

2. The code separately handles `stdDev = 0` and `strike = 0` as degenerate cases to avoid
   division by zero in `ln(F'/K')` and `ln(F'/K')/σ`.

3. The `QL_ENSURE(result >= 0)` at the end is a defensive check — the formula should
   mathematically always produce non-negative results for valid inputs.

## Open Questions

1. **Displacement interaction with put-call parity**: Does put-call parity hold exactly as
   `Call − Put = D · (F − K)` or as `D · (F' − K')` = `D · (F − K)` (since F' − K' = F − K)?
   The displacement cancels, so the standard form holds. *Resolved: yes, displacement cancels.*

2. **Numerical stability**: For extreme d₁/d₂ values, the CDF product `Φ(d₁) · F'` could
   lose precision. The code does not use a specialised log-space computation. This is a
   potential source of numerical error but outside the scope of our real-valued model.

## Composition with Existing Targets

- **NormalDistribution** (Phase 5): BlackFormula uses `CumulativeNormalDistribution` (Φ).
  Our Lean model of the CDF can be reused directly, making BlackFormula a natural
  *composition target* that builds on prior work.
- **InterestRate** (Phase 5): Interest rates often feed into `discount` and `forward` —
  verifying BlackFormula provides end-to-end confidence.

## Spec-to-Implementation Complexity Ratio: **High**

The key properties (put-call parity, non-negativity, ATM symmetry, monotonicity) are
clean algebraic statements, each expressible in 1–3 lines of Lean. The C++ implementation
is ~100 lines of non-trivial code with special cases, displacement handling, and defensive
checks. This makes BlackFormula an excellent FV target.
