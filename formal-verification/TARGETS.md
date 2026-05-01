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
| 9 | FloatingPointClose | `ql/math/comparison.hpp` | 1 — Research | ⬜ Identified | Medium-High | High |

## Phase Key

1. **Research** — target identified, properties outlined
2. **Informal Spec** — precise English specification written
3. **Lean Spec** — Lean 4 types and theorem statements (with `sorry`)
4. **Implementation** — Lean 4 functional model of the C++ code
5. **Proofs** — theorems proved (partially or fully)
