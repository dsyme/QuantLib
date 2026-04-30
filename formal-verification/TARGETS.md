# Formal Verification Targets — QuantLib

🔬 *Lean Squad — automated formal verification.*

| # | Target | Files | Phase | Status | Priority | Spec-to-Impl Ratio |
|---|--------|-------|-------|--------|----------|---------------------|
| 1 | InterestRate | `ql/interestrate.hpp/cpp` | 2 — Informal Spec | 🔄 In progress | **Top** | High |
| 2 | Actual360 | `ql/time/daycounters/actual360.hpp` | 2 — Informal Spec | 🔄 In progress | High | High |
| 3 | LinearInterpolation | `ql/math/interpolations/linearinterpolation.hpp` | 1 — Research | ⬜ Not started | Medium | Medium-High |
| 4 | Thirty360 | `ql/time/daycounters/thirty360.hpp/cpp` | 2 — Informal Spec | 🔄 In progress | Medium | Medium |
| 5 | NormalDistribution | `ql/math/distributions/normaldistribution.hpp/cpp` | 1 — Research | ⬜ Not started | Low | Medium |

## Phase Key

1. **Research** — target identified, properties outlined
2. **Informal Spec** — precise English specification written
3. **Lean Spec** — Lean 4 types and theorem statements (with `sorry`)
4. **Implementation** — Lean 4 functional model of the C++ code
5. **Proofs** — theorems proved (partially or fully)
