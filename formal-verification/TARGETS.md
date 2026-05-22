# Formal Verification Targets — QuantLib

🔬 *Lean Squad — automated formal verification.*

| # | Target | Files | Phase | Status | Priority | Spec-to-Impl Ratio |
|---|--------|-------|-------|--------|----------|---------------------|
| 1 | InterestRate | `ql/interestrate.hpp/cpp` | 5 — Proofs | 🔄 30/33 proved (3 Float sorry) | **Top** | High |
| 2 | Actual360 | `ql/time/daycounters/actual360.hpp` | 5 — Proofs | ✅ 8/8 proved + correspondence | High | High |
| 3 | LinearInterpolation | `ql/math/interpolations/linearinterpolation.hpp` | 5 — Proofs | ✅ 7/7 proved + correspondence | Medium | Medium-High |
| 4 | Thirty360 | `ql/time/daycounters/thirty360.hpp/cpp` | 5 — Proofs | ✅ 11/11 proved (EU convention) | Medium | Medium-High |
| 5 | NormalDistribution | `ql/math/distributions/normaldistribution.hpp/cpp` | 5 — Proofs | 🔄 15/16 proved (1 sorry) | Low | Medium |
| 6 | Factorial | `ql/math/factorial.hpp/cpp` | 5 — Proofs | ✅ 10/10 proved | Medium | High |
| 7 | Bisection | `ql/math/solvers1d/bisection.hpp` | 5 — Proofs | ✅ 15/15 proved | Medium | High |
| 8 | Actual365Fixed | `ql/time/daycounters/actual365fixed.hpp` | 5 — Proofs | ✅ 8/8 proved | Medium | High |
| 9 | FloatingPointClose | `ql/math/comparison.hpp` | 5 — Proofs | ✅ 12/12 proved + correspondence | Medium-High | High |
| 10 | BlackFormula | `ql/pricingengines/blackformula.hpp/cpp` | 5 — Proofs | 🔄 14/15 proved (1 sorry) | **High** | High |
| 11 | Matrix | `ql/math/matrix.hpp/cpp` | 5 — Proofs | ✅ 23/23 proved + correspondence | Medium | High |
| 12 | NewtonSafe | `ql/math/solvers1d/newtonsafe.hpp` | 5 — Proofs | ✅ 13/13 proved + correspondence | Medium-High | Medium-High |
| 13 | Rounding | `ql/math/rounding.hpp/cpp` | 5 — Proofs | ✅ 20/20 proved + correspondence | **High** | High |
| 14 | PrimeNumbers | `ql/math/primenumbers.hpp/cpp` | 5 — Proofs | ✅ 14/14 proved | Medium | High |
| 15 | BernsteinPolynomial | `ql/math/bernsteinpolynomial.hpp/cpp` | 2 — Informal Spec | 🔄 Spec written | Medium | High |
| 16 | RichardsonExtrapolation | `ql/math/richardsonextrapolation.hpp` | 1 — Research | ⬜ Identified | Medium-High | High |
| 17 | LagrangeInterpolation | `ql/math/interpolations/lagrangeinterpolation.hpp` | 2 — Informal Spec | 🔄 Spec written | Medium | Medium-High |
| 18 | Schedule | `ql/time/schedule.hpp/cpp` | 1 — Research | ⬜ Identified | Lower | Medium |
| 19 | Brent | `ql/math/solvers1d/brent.hpp` | 2 — Informal Spec | 🔄 Spec written | Medium-High | High |
| 20 | BinomialDistribution | `ql/math/distributions/binomialdistribution.hpp` | 2 — Informal Spec | 🔄 Spec written | Medium | High |

## Phase Key

1. **Research** — target identified, properties outlined
2. **Informal Spec** — precise English specification written
3. **Lean Spec** — Lean 4 types and theorem statements (with `sorry`)
4. **Implementation** — Lean 4 functional model of the C++ code
5. **Proofs** — theorems proved (partially or fully)
