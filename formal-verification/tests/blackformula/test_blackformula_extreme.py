#!/usr/bin/env python3
"""
BlackFormula Extended Correspondence Tests — Extreme Parameters

🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

This supplement tests the BlackFormula properties under extreme parameter
regimes that stress numerical stability: very deep ITM/OTM, very high/low
volatility, near-zero forward/strike, and large displacements.

These test the same Lean theorems as the base test but on parameter ranges
where floating-point issues are most likely to reveal model/implementation
divergence.
"""

import math
import sys

TOL = 1e-10
REL_TOL = 1e-9


def norm_cdf(x: float) -> float:
    return 0.5 * math.erfc(-x / math.sqrt(2.0))


def black_formula(option_type: str, strike: float, forward: float,
                  std_dev: float, discount: float = 1.0,
                  displacement: float = 0.0) -> float:
    sign = 1.0 if option_type == "Call" else -1.0
    F = forward + displacement
    K = strike + displacement

    if std_dev == 0.0:
        return max(sign * (forward - strike), 0.0) * discount

    if K <= 0.0:
        return (F * discount) if option_type == "Call" else 0.0

    d1 = math.log(F / K) / std_dev + 0.5 * std_dev
    d2 = d1 - std_dev
    nd1 = norm_cdf(sign * d1)
    nd2 = norm_cdf(sign * d2)
    return discount * sign * (F * nd1 - K * nd2)


def run_tests():
    passed = 0
    failed = 0
    errors_list = []

    # --- Extreme vol tests ---
    # Very high vol: call should approach D*F (put approaches D*K)
    for F in [10.0, 100.0, 1000.0]:
        for K in [10.0, 100.0, 1000.0]:
            for D in [0.95, 1.0]:
                sigma = 50.0  # extremely high vol
                call = black_formula("Call", K, F, sigma, D, 0.0)
                put = black_formula("Put", K, F, sigma, D, 0.0)
                # Non-negativity (P1)
                if call < -TOL:
                    errors_list.append(f"High vol nonneg call: F={F} K={K} σ={sigma} call={call}")
                    failed += 1; continue
                if put < -TOL:
                    errors_list.append(f"High vol nonneg put: F={F} K={K} σ={sigma} put={put}")
                    failed += 1; continue
                # Put-call parity (P2)
                pcp = call - put - D * (F - K)
                if abs(pcp) > TOL + REL_TOL * max(abs(call), abs(put), 1.0):
                    errors_list.append(f"High vol PCP: F={F} K={K} σ={sigma} residual={pcp}")
                    failed += 1; continue
                # Upper bounds (P7)
                if call > D * F + TOL:
                    errors_list.append(f"High vol call bound: {call} > {D*F}")
                    failed += 1; continue
                if put > D * K + TOL:
                    errors_list.append(f"High vol put bound: {put} > {D*K}")
                    failed += 1; continue
                passed += 1

    # --- Very low vol (near zero but positive) ---
    for F in [80.0, 100.0, 120.0]:
        for K in [80.0, 100.0, 120.0]:
            sigma = 1e-8
            call = black_formula("Call", K, F, sigma, 1.0, 0.0)
            put = black_formula("Put", K, F, sigma, 1.0, 0.0)
            # Should approach intrinsic (with small time-value residual at ATM)
            intrinsic_call = max(F - K, 0.0)
            intrinsic_put = max(K - F, 0.0)
            # ATM case: time value ≈ σ*F/√(2π) which is ~4e-7 for σ=1e-8, F=100
            atm_tol = sigma * max(F, K) + TOL
            if abs(call - intrinsic_call) > atm_tol + REL_TOL * max(intrinsic_call, 1.0):
                errors_list.append(f"Low vol call intrinsic: F={F} K={K} got={call} exp={intrinsic_call}")
                failed += 1; continue
            if abs(put - intrinsic_put) > atm_tol + REL_TOL * max(intrinsic_put, 1.0):
                errors_list.append(f"Low vol put intrinsic: F={F} K={K} got={put} exp={intrinsic_put}")
                failed += 1; continue
            # PCP
            pcp = call - put - (F - K)
            if abs(pcp) > TOL + REL_TOL * max(abs(F - K), 1.0):
                errors_list.append(f"Low vol PCP: F={F} K={K} residual={pcp}")
                failed += 1; continue
            passed += 1

    # --- Deep ITM/OTM ---
    for ratio in [0.01, 0.1, 10.0, 100.0]:
        F = 100.0
        K = F * ratio
        for sigma in [0.2, 1.0, 5.0]:
            if K <= 0:
                continue
            call = black_formula("Call", K, F, sigma, 1.0, 0.0)
            put = black_formula("Put", K, F, sigma, 1.0, 0.0)
            # Non-negativity
            if call < -TOL or put < -TOL:
                errors_list.append(f"Deep ITM/OTM nonneg: F={F} K={K} σ={sigma} call={call} put={put}")
                failed += 1; continue
            # PCP
            pcp = call - put - (F - K)
            if abs(pcp) > TOL + REL_TOL * max(abs(F - K), abs(call), 1.0):
                errors_list.append(f"Deep ITM/OTM PCP: F={F} K={K} σ={sigma} residual={pcp}")
                failed += 1; continue
            # Upper bounds
            if call > F + TOL:
                errors_list.append(f"Deep ITM call bound: {call} > {F}")
                failed += 1; continue
            if put > K + TOL:
                errors_list.append(f"Deep OTM put bound: {put} > {K}")
                failed += 1; continue
            passed += 1

    # --- Large displacement ---
    for delta in [50.0, 500.0, 5000.0]:
        F = 100.0
        K = 100.0
        sigma = 0.2
        call = black_formula("Call", K, F, sigma, 1.0, delta)
        put = black_formula("Put", K, F, sigma, 1.0, delta)
        # ATM symmetry with displacement
        if abs(call - put) > TOL + REL_TOL * max(abs(call), 1.0):
            errors_list.append(f"Large disp ATM: δ={delta} call={call} put={put}")
            failed += 1; continue
        # PCP: call - put = F - K = 0
        if abs(call - put) > TOL:
            errors_list.append(f"Large disp PCP: δ={delta} residual={call - put}")
            failed += 1; continue
        # Nonneg
        if call < -TOL or put < -TOL:
            errors_list.append(f"Large disp nonneg: δ={delta}")
            failed += 1; continue
        passed += 1

    # --- Monotonicity stress: fine-grained forward grid ---
    K = 100.0
    sigma = 0.3
    forwards = [F * 0.01 for F in range(1, 501)]  # 0.01 to 5.0 * 100
    prev_call = None
    mono_fwd_ok = True
    for F in forwards:
        call = black_formula("Call", K, F, sigma, 1.0, 0.0)
        if prev_call is not None and call < prev_call - TOL:
            errors_list.append(f"Mono fwd stress: F={F} call={call} < prev={prev_call}")
            mono_fwd_ok = False
            failed += 1
            break
        prev_call = call
    if mono_fwd_ok:
        passed += 1

    # --- Monotonicity stress: fine-grained vol grid ---
    F = 100.0
    K = 120.0  # OTM call
    vols = [v * 0.01 for v in range(1, 301)]  # 0.01 to 3.0
    prev_call = None
    mono_vol_ok = True
    for sigma in vols:
        call = black_formula("Call", K, F, sigma, 1.0, 0.0)
        if prev_call is not None and call < prev_call - TOL:
            errors_list.append(f"Mono vol stress: σ={sigma} call={call} < prev={prev_call}")
            mono_vol_ok = False
            failed += 1
            break
        prev_call = call
    if mono_vol_ok:
        passed += 1

    # --- Discount linearity at extreme discounts ---
    for D in [0.001, 0.01, 0.5, 0.999, 1.0]:
        F = 100.0
        K = 110.0
        sigma = 0.25
        call = black_formula("Call", K, F, sigma, D, 0.0)
        call_unit = black_formula("Call", K, F, sigma, 1.0, 0.0)
        if abs(call - D * call_unit) > TOL + REL_TOL * max(abs(call), 1e-10):
            errors_list.append(f"Discount linearity: D={D} call={call} vs {D*call_unit}")
            failed += 1
        else:
            passed += 1

    # --- Zero forward edge case ---
    # When F → 0+, call → 0 and put → D*K
    for K in [50.0, 100.0]:
        for sigma in [0.2, 1.0]:
            F = 1e-10
            D = 1.0
            call = black_formula("Call", K, F, sigma, D, 0.0)
            put = black_formula("Put", K, F, sigma, D, 0.0)
            if call < -TOL:
                errors_list.append(f"Zero fwd call nonneg: {call}")
                failed += 1; continue
            if put < -TOL:
                errors_list.append(f"Zero fwd put nonneg: {put}")
                failed += 1; continue
            # Put should approach D*K for very small forward
            if abs(put - D * K) > 1.0:  # loose tolerance for near-zero forward
                errors_list.append(f"Zero fwd put ≈ DK: put={put} vs DK={D*K}")
                failed += 1; continue
            passed += 1

    print(f"=== BlackFormula Extended (Extreme Parameters) ===")
    print(f"Tests: {passed} passed, {failed} failed")
    if errors_list:
        for e in errors_list:
            print(f"  FAIL: {e}")
    else:
        print("✅ All extended correspondence tests PASSED")
    return failed


if __name__ == "__main__":
    failures = run_tests()
    sys.exit(1 if failures > 0 else 0)
