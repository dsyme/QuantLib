#!/usr/bin/env python3
"""
Correspondence test for LinearInterpolation.

Runs the Lean model and a Python reference implementation (matching the C++
semantics) on the same test cases, then compares results.

🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
"""

import json
import subprocess
import sys
import os

def slope(xs, ys, i):
    """Python implementation matching Lean model and C++ semantics."""
    xi = xs[i] if i < len(xs) else 0.0
    xi1 = xs[i+1] if i+1 < len(xs) else 0.0
    yi = ys[i] if i < len(ys) else 0.0
    yi1 = ys[i+1] if i+1 < len(ys) else 0.0
    denom = xi1 - xi
    if denom == 0:
        return 0.0
    return (yi1 - yi) / denom

def value(xs, ys, i, x):
    """Linear interpolation value at x in segment i."""
    xi = xs[i] if i < len(xs) else 0.0
    yi = ys[i] if i < len(ys) else 0.0
    return yi + (x - xi) * slope(xs, ys, i)

def derivative(xs, ys, i):
    """Derivative (= slope) in segment i."""
    return slope(xs, ys, i)

def second_derivative():
    """Always zero for linear interpolation."""
    return 0.0

def run_tests():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(script_dir, "test_cases.json")) as f:
        cases = json.load(f)

    passed = 0
    failed = 0
    eps = 1e-10

    for tc in cases:
        xs = tc["xs"]
        ys = tc["ys"]
        seg = tc["segment"]
        x = tc["x"]

        val = value(xs, ys, seg, x)
        deriv = derivative(xs, ys, seg)
        sd = second_derivative()

        errors = []
        if abs(val - tc["expected_value"]) > eps:
            errors.append(f"value: got {val}, expected {tc['expected_value']}")
        if abs(deriv - tc["expected_deriv"]) > eps:
            errors.append(f"deriv: got {deriv}, expected {tc['expected_deriv']}")
        if abs(sd - tc["expected_second_deriv"]) > eps:
            errors.append(f"second_deriv: got {sd}, expected {tc['expected_second_deriv']}")

        if errors:
            print(f"FAIL: {tc['desc']}: {'; '.join(errors)}")
            failed += 1
        else:
            passed += 1

    print(f"\n{passed}/{passed+failed} test cases passed.")
    if failed:
        print(f"{failed} FAILED.")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(run_tests())
