#!/usr/bin/env python3
"""
Correspondence tests for FVSquad.Composition — verifying that the Lean model's
algebraic properties hold for the QuantLib concepts being modelled.

🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

These tests validate the Lean Composition module against the intended QuantLib
behaviour by running the same computations in Python (mirroring the C++ semantics)
and checking them against the Lean model's predictions.
"""

import sys

passed = 0
failed = 0

def check(name, actual, expected):
    global passed, failed
    if actual == expected:
        passed += 1
    else:
        failed += 1
        print(f"FAIL: {name}: got {actual}, expected {expected}")

# --- Day Count Properties ---
def dayCount(d1, d2):
    return d2 - d1

# Additivity
for d1 in range(-5, 6):
    for d2 in range(-5, 6):
        for d3 in range(-5, 6):
            check("dayCount_additive", dayCount(d1, d2) + dayCount(d2, d3), dayCount(d1, d3))

# Antisymmetry
for d1 in range(-10, 11):
    for d2 in range(-10, 11):
        check("dayCount_antisymm", dayCount(d1, d2), -dayCount(d2, d1))

# Self
for d in range(-20, 21):
    check("dayCount_self", dayCount(d, d), 0)

# Monotonicity
for d1 in range(-5, 6):
    for d2 in range(-5, 6):
        for d3 in range(d2, 6):
            check("dayCount_mono", dayCount(d1, d2) <= dayCount(d1, d3), True)

# Translation invariance
for d1 in range(-5, 6):
    for d2 in range(-5, 6):
        for k in range(-5, 6):
            check("dayCount_translate", dayCount(d1+k, d2+k), dayCount(d1, d2))

# --- Payoff Properties ---
def callPayoff(K, S):
    return max(S - K, 0)

def putPayoff(K, S):
    return max(K - S, 0)

# Non-negativity
for K in range(-20, 21):
    for S in range(-20, 21):
        check("callPayoff_nonneg", callPayoff(K, S) >= 0, True)
        check("putPayoff_nonneg", putPayoff(K, S) >= 0, True)

# Put-call parity
for K in range(-20, 21):
    for S in range(-20, 21):
        check("putCallParity", callPayoff(K, S) - putPayoff(K, S), S - K)

# Call monotonicity
for K in range(-10, 11):
    for S1 in range(-10, 11):
        for S2 in range(S1, 11):
            check("callPayoff_mono", callPayoff(K, S1) <= callPayoff(K, S2), True)

# Put anti-monotonicity
for K in range(-10, 11):
    for S1 in range(-10, 11):
        for S2 in range(S1, 11):
            check("putPayoff_antimono", putPayoff(K, S2) <= putPayoff(K, S1), True)

# ATM zero
for K in range(-20, 21):
    check("atm_zero_call", callPayoff(K, K), 0)
    check("atm_zero_put", putPayoff(K, K), 0)

# OTM
for K in range(-10, 11):
    for S in range(-10, K+1):
        check("call_otm", callPayoff(K, S), 0)
    for S in range(K, 11):
        check("put_otm", putPayoff(K, S), 0)

# ITM values
for K in range(-10, 11):
    for S in range(K, 11):
        check("call_itm", callPayoff(K, S), S - K)
    for S in range(-10, K+1):
        check("put_itm", putPayoff(K, S), K - S)

# --- Discounting Properties ---
def discounted(value, df):
    return value * df

# Discount one
for v in range(-20, 21):
    check("discount_one", discounted(v, 1), v)

# Discount zero
for v in range(-20, 21):
    check("discount_zero", discounted(v, 0), 0)

# Discount chain (associativity)
for v in range(-5, 6):
    for df1 in range(-5, 6):
        for df2 in range(-5, 6):
            check("discount_chain", discounted(discounted(v, df1), df2), discounted(v, df1 * df2))

# Discount preserves parity
for K in range(-10, 11):
    for S in range(-10, 11):
        for df in range(-5, 6):
            lhs = discounted(callPayoff(K, S), df) - discounted(putPayoff(K, S), df)
            rhs = discounted(S - K, df)
            check("discount_preserves_parity", lhs, rhs)

# Discounted call non-negativity (df >= 0)
for K in range(-10, 11):
    for S in range(-10, 11):
        for df in range(0, 6):
            check("discounted_call_nonneg", discounted(callPayoff(K, S), df) >= 0, True)
            check("discounted_put_nonneg", discounted(putPayoff(K, S), df) >= 0, True)

# Discounted call monotonicity (df >= 0)
for K in range(-5, 6):
    for S1 in range(-5, 6):
        for S2 in range(S1, 6):
            for df in range(0, 4):
                check("discounted_call_mono",
                      discounted(callPayoff(K, S1), df) <= discounted(callPayoff(K, S2), df), True)

# --- Compounding Properties ---
def compoundNumerator(principal, rateBps, days):
    return principal * (10000 + rateBps * days)

# Zero days
for p in range(-10, 11):
    for r in range(-10, 11):
        check("compound_zero_days", compoundNumerator(p, r, 0), p * 10000)

# Zero rate
for p in range(-10, 11):
    for d in range(-10, 11):
        check("compound_zero_rate", compoundNumerator(p, 0, d), p * 10000)

# Linear in principal
for p1 in range(-5, 6):
    for p2 in range(-5, 6):
        for r in range(-5, 6):
            for d in range(-5, 6):
                check("compound_linear_principal",
                      compoundNumerator(p1 + p2, r, d),
                      compoundNumerator(p1, r, d) + compoundNumerator(p2, r, d))

# Monotone in rate (p > 0, d > 0)
for p in range(1, 6):
    for r1 in range(-5, 6):
        for r2 in range(r1, 6):
            for d in range(1, 6):
                check("compound_mono_rate",
                      compoundNumerator(p, r1, d) <= compoundNumerator(p, r2, d), True)

# Monotone in days (p > 0, r > 0)
for p in range(1, 6):
    for r in range(1, 6):
        for d1 in range(-5, 6):
            for d2 in range(d1, 6):
                check("compound_mono_days",
                      compoundNumerator(p, r, d1) <= compoundNumerator(p, r, d2), True)

print(f"\n{'='*60}")
print(f"Composition correspondence tests: {passed} passed, {failed} failed")
print(f"Total test cases: {passed + failed}")
print(f"{'='*60}")

sys.exit(0 if failed == 0 else 1)
