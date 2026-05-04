# Informal Specification: PlainVanillaPayoff

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Source

`ql/instruments/payoffs.hpp` / `ql/instruments/payoffs.cpp` — `PlainVanillaPayoff`

## Purpose

The plain vanilla payoff is the most fundamental option payoff function in finance:
- **Call**: `payoff(S) = max(S - K, 0)`
- **Put**: `payoff(S) = max(K - S, 0)`

where `S` is the underlying price and `K` is the strike price.

## Preconditions

- `S` (price) is a real number (typically ≥ 0)
- `K` (strike) is a real number (typically > 0)
- Option type is either Call or Put

## Postconditions

- The payoff is always non-negative: `payoff(S) ≥ 0`
- Call payoff: `max(S - K, 0)`
- Put payoff: `max(K - S, 0)`

## Invariants / Key Properties

1. **Non-negativity**: Both call and put payoffs are ≥ 0
2. **Put-call parity**: `call(S) - put(S) = S - K`
3. **Out-of-the-money**: Call is 0 when S ≤ K; Put is 0 when S ≥ K
4. **In-the-money**: Call equals S - K when S ≥ K; Put equals K - S when S ≤ K
5. **At-the-money**: Both payoffs are 0 when S = K
6. **Call monotonicity**: Call payoff is non-decreasing in S
7. **Put monotonicity**: Put payoff is non-increasing in S
8. **Convexity**: Both payoff functions are convex
9. **Symmetry**: call(K, S) = put(S, K) — swapping strike and price swaps call/put

## Edge Cases

- S = K (at-the-money): both payoffs = 0
- S = 0: call = 0, put = K
- K = 0: call = S, put = 0

## Examples

| Type | S | K | Payoff |
|------|---|---|--------|
| Call | 110 | 100 | 10 |
| Call | 90 | 100 | 0 |
| Put | 110 | 100 | 0 |
| Put | 90 | 100 | 10 |

## Spec-to-Implementation Complexity Ratio

**High** — The spec (max(S-K, 0) / max(K-S, 0)) is trivially stated, but the
implementation sits within a class hierarchy (Payoff → TypePayoff → StrikedTypePayoff → PlainVanillaPayoff) with visitor pattern, virtual dispatch, and option type switching. The algebraic properties (put-call parity, convexity, monotonicity) are non-trivial consequences of the simple definition.
