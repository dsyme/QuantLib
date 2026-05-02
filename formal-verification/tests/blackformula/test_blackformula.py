#!/usr/bin/env python3
"""
BlackFormula Correspondence Tests

🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

Tests algebraic properties of the Black 1976 formula that correspond to
theorems proved in FVSquad.BlackFormula.lean. These tests execute a Python
implementation of the Black formula (matching the C++ semantics) and verify
the same properties that Lean proves over exact reals.

Properties tested:
  P1. Non-negativity (zero-vol and general)
  P2. Put-call parity: Call - Put = D * (F - K)
  P3. Zero volatility limit = intrinsic value
  P4. ATM symmetry: Call = Put when F = K
  P5. Monotonicity in forward (call)
  P6. Monotonicity in stdDev (vega >= 0)
  P7. Upper bounds: Call <= D*(F+δ), Put <= D*(K+δ)
  P8. Linearity in discount
  P9. Zero strike call = D*F
"""

import math
import json
import sys
from typing import List, Tuple

# Tolerance for floating-point comparisons
TOL = 1e-12
REL_TOL = 1e-10


def norm_cdf(x: float) -> float:
    """Standard normal CDF using erfc for numerical stability."""
    return 0.5 * math.erfc(-x / math.sqrt(2.0))


def black_formula(option_type: str, strike: float, forward: float,
                  std_dev: float, discount: float = 1.0,
                  displacement: float = 0.0) -> float:
    """Black 1976 formula matching QuantLib's blackFormula semantics."""
    sign = 1.0 if option_type == "Call" else -1.0
    F = forward + displacement
    K = strike + displacement

    if std_dev == 0.0:
        return max(sign * (forward - strike), 0.0) * discount

    if K == 0.0:
        return (F * discount) if option_type == "Call" else 0.0

    d1 = math.log(F / K) / std_dev + 0.5 * std_dev
    d2 = d1 - std_dev
    nd1 = norm_cdf(sign * d1)
    nd2 = norm_cdf(sign * d2)
    result = discount * sign * (F * nd1 - K * nd2)
    return result


# --- Test cases ---

def test_cases() -> List[dict]:
    """Generate test parameter sets."""
    cases = []
    forwards = [50.0, 100.0, 150.0]
    strikes = [80.0, 100.0, 120.0]
    stddevs = [0.0, 0.05, 0.2, 0.5, 1.0]
    discounts = [0.9, 0.95, 1.0]
    displacements = [0.0, 5.0]

    for F in forwards:
        for K in strikes:
            for sigma in stddevs:
                for D in discounts:
                    for delta in displacements:
                        cases.append({"F": F, "K": K, "sigma": sigma,
                                      "D": D, "delta": delta})
    return cases


def run_tests():
    passed = 0
    failed = 0
    results = []

    cases = test_cases()

    for i, c in enumerate(cases):
        F, K, sigma, D, delta = c["F"], c["K"], c["sigma"], c["D"], c["delta"]
        call = black_formula("Call", K, F, sigma, D, delta)
        put = black_formula("Put", K, F, sigma, D, delta)
        errors = []

        # P1: Non-negativity
        if call < -TOL:
            errors.append(f"P1 call nonneg: {call}")
        if put < -TOL:
            errors.append(f"P1 put nonneg: {put}")

        # P2: Put-call parity (sigma > 0 only)
        if sigma > 0 and K + delta > 0 and F + delta > 0:
            pcp = call - put - D * (F - K)
            if abs(pcp) > TOL + REL_TOL * abs(D * (F - K)):
                errors.append(f"P2 put-call parity: residual={pcp}")

        # P3: Zero vol => intrinsic
        if sigma == 0.0:
            intrinsic_call = max(F - K, 0.0) * D
            intrinsic_put = max(K - F, 0.0) * D
            if abs(call - intrinsic_call) > TOL:
                errors.append(f"P3 zero-vol call: {call} vs {intrinsic_call}")
            if abs(put - intrinsic_put) > TOL:
                errors.append(f"P3 zero-vol put: {put} vs {intrinsic_put}")

        # P7: Upper bounds
        if call > D * (F + delta) + TOL:
            errors.append(f"P7 call upper: {call} > {D*(F+delta)}")
        if put > D * (K + delta) + TOL:
            errors.append(f"P7 put upper: {put} > {D*(K+delta)}")

        # P8: Linearity in discount
        call_unit = black_formula("Call", K, F, sigma, 1.0, delta)
        if abs(call - D * call_unit) > TOL + REL_TOL * abs(call):
            errors.append(f"P8 linear discount: {call} vs {D}*{call_unit}")

        if errors:
            failed += 1
            results.append({"case": i, "params": c, "errors": errors})
        else:
            passed += 1

    # P4: ATM symmetry tests
    for sigma in [0.05, 0.2, 0.5, 1.0]:
        for F in [50.0, 100.0, 150.0]:
            call = black_formula("Call", F, F, sigma, 1.0, 0.0)
            put = black_formula("Put", F, F, sigma, 1.0, 0.0)
            if abs(call - put) > TOL:
                failed += 1
                results.append({"case": "ATM", "params": {"F": F, "sigma": sigma},
                                "errors": [f"P4 ATM symmetry: call={call} put={put}"]})
            else:
                passed += 1

    # P5: Monotonicity in forward (call)
    for K in [80.0, 100.0, 120.0]:
        for sigma in [0.2, 0.5]:
            for delta in [0.0, 5.0]:
                prev = None
                mono_ok = True
                for F in [50.0, 75.0, 100.0, 125.0, 150.0]:
                    val = black_formula("Call", K, F, sigma, 1.0, delta)
                    if prev is not None and val < prev - TOL:
                        mono_ok = False
                        failed += 1
                        results.append({"case": "mono_fwd", "errors":
                                        [f"P5 mono forward: F={F} val={val} < prev={prev}"]})
                        break
                    prev = val
                if mono_ok:
                    passed += 1

    # P6: Monotonicity in stdDev
    for F in [100.0]:
        for K in [80.0, 100.0, 120.0]:
            for delta in [0.0]:
                for otype in ["Call", "Put"]:
                    prev = None
                    mono_ok = True
                    for sigma in [0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0]:
                        val = black_formula(otype, K, F, sigma, 1.0, delta)
                        if prev is not None and val < prev - TOL:
                            mono_ok = False
                            failed += 1
                            results.append({"case": "mono_vol", "errors":
                                            [f"P6 mono vol ({otype}): σ={sigma} val={val} < prev={prev}"]})
                            break
                        prev = val
                    if mono_ok:
                        passed += 1

    # P9: Zero strike call
    for F in [50.0, 100.0, 150.0]:
        for sigma in [0.2, 0.5]:
            for D in [0.9, 1.0]:
                val = black_formula("Call", 0.0, F, sigma, D, 0.0)
                expected = D * F
                if abs(val - expected) > TOL:
                    failed += 1
                    results.append({"case": "zero_strike", "errors":
                                    [f"P9 zero strike: {val} vs {expected}"]})
                else:
                    passed += 1

    print(f"BlackFormula correspondence tests: {passed} passed, {failed} failed")
    if results:
        for r in results:
            print(f"  FAIL: {r}")
    return failed


if __name__ == "__main__":
    failures = run_tests()
    sys.exit(1 if failures > 0 else 0)
