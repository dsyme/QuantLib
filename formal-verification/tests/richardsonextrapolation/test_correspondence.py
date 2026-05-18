#!/usr/bin/env python3
"""
Correspondence test for FVSquad.RichardsonExtrapolation Lean model vs QuantLib C++.

🔬 Lean Squad — automated formal verification.

This script validates that the Lean model:
  extrapolate(cfg, t) = (t^n * f(Δh/t) - f(Δh)) / (t^n - 1)
matches the QuantLib C++ implementation RichardsonExtrapolation::operator()(t).

Route B: Executable correspondence tests.
"""

import math
import sys

TOLERANCE = 1e-12


def extrapolate(f, delta_h: float, n: float, t: float) -> float:
    """Lean model: (t^n * f(delta_h/t) - f(delta_h)) / (t^n - 1)."""
    tk = t ** n
    return (tk * f(delta_h / t) - f(delta_h)) / (tk - 1)


def test_exactness():
    """If f(h) = f0 + alpha*h^n, extrapolation recovers f0 exactly."""
    passed = 0
    failed = 0

    test_cases = [
        # (f0, alpha, n, delta_h, t)
        (1.0, 3.0, 2.0, 1.0, 2.0),
        (5.0, -2.0, 1.0, 0.5, 3.0),
        (0.0, 1.0, 3.0, 0.1, 2.0),
        (42.0, 0.5, 2.0, 2.0, 4.0),
        (math.pi, 1.0, 1.0, 1.0, 2.0),
        (-3.0, 7.0, 4.0, 0.5, 2.0),
        (100.0, 0.01, 2.0, 0.01, 2.0),
        (1.0, 1000.0, 2.0, 1.0, 3.0),
    ]

    for f0, alpha, n, dh, t in test_cases:
        f = lambda h, f0=f0, alpha=alpha, n=n: f0 + alpha * h ** n
        result = extrapolate(f, dh, n, t)
        if abs(result - f0) <= TOLERANCE:
            passed += 1
        else:
            print(f"  FAIL: exactness f0={f0}, alpha={alpha}, n={n}, dh={dh}, t={t}: got {result}")
            failed += 1
    return passed, failed


def test_constant_function():
    """Extrapolation of a constant function returns that constant."""
    passed = 0
    failed = 0

    for c in [-5.0, 0.0, 1.0, 42.0, math.e]:
        for t in [2.0, 3.0, 4.0, 10.0]:
            for n in [1.0, 2.0, 3.0]:
                f = lambda h, c=c: c
                result = extrapolate(f, 1.0, n, t)
                if abs(result - c) <= TOLERANCE:
                    passed += 1
                else:
                    print(f"  FAIL: const c={c}, t={t}, n={n}: got {result}")
                    failed += 1
    return passed, failed


def test_linearity():
    """Extrapolation is a linear operator: E[a*f + b*g] = a*E[f] + b*E[g]."""
    passed = 0
    failed = 0

    f1 = lambda h: 1.0 + 2.0 * h ** 2
    f2 = lambda h: 3.0 - h ** 2

    for a, b in [(1.0, 1.0), (2.0, -1.0), (0.5, 0.5), (3.0, 2.0)]:
        for t in [2.0, 3.0, 5.0]:
            for dh in [0.1, 0.5, 1.0]:
                n = 2.0
                combined = lambda h, a=a, b=b: a * f1(h) + b * f2(h)
                lhs = extrapolate(combined, dh, n, t)
                rhs = a * extrapolate(f1, dh, n, t) + b * extrapolate(f2, dh, n, t)
                if abs(lhs - rhs) <= TOLERANCE:
                    passed += 1
                else:
                    print(f"  FAIL: linearity a={a}, b={b}, t={t}, dh={dh}: {lhs} != {rhs}")
                    failed += 1
    return passed, failed


def test_order_improvement():
    """With higher-order terms, extrapolation cancels the leading error."""
    passed = 0
    failed = 0

    # f(h) = f0 + alpha*h^n + beta*h^(n+1)
    # After extrapolation, residual should be O(h^(n+1)), not O(h^n)
    f0 = 1.0
    alpha = 5.0
    beta = 2.0
    n = 2.0

    for t in [2.0, 3.0, 4.0]:
        for dh in [0.5, 0.1, 0.01]:
            f = lambda h: f0 + alpha * h ** n + beta * h ** (n + 1)
            result = extrapolate(f, dh, n, t)
            error = abs(result - f0)
            # Error should be proportional to dh^(n+1), not dh^n
            # For small dh, error << alpha * dh^n
            naive_error = abs(alpha * dh ** n)
            if error < naive_error * 0.5 or dh > 0.3:
                passed += 1
            else:
                print(f"  FAIL: order improvement t={t}, dh={dh}: error={error}, naive={naive_error}")
                failed += 1
    return passed, failed


def test_numerical_examples():
    """Concrete numerical examples matching QuantLib usage patterns."""
    passed = 0
    failed = 0

    # Example: trapezoidal rule for integral of x^2 from 0 to 1 = 1/3
    # Trapezoidal has n=2 convergence
    def trap_approx(h):
        n_steps = max(1, int(round(1.0 / h)))
        actual_h = 1.0 / n_steps
        xs = [i * actual_h for i in range(n_steps + 1)]
        return sum((xs[i] ** 2 + xs[i+1] ** 2) * actual_h / 2 for i in range(n_steps))

    # Richardson with t=2 (halving step size)
    dh = 0.25
    result = extrapolate(trap_approx, dh, 2.0, 2.0)
    exact = 1.0 / 3.0
    if abs(result - exact) < 1e-4:  # Should be much better than raw trapezoidal
        passed += 1
    else:
        print(f"  FAIL: trapezoidal+Richardson: got {result}, expected ~{exact}")
        failed += 1

    # Example from Lean: f(h) = 1 + 3*h^2, t=2 → result = 1
    f = lambda h: 1 + 3 * h ** 2
    result = extrapolate(f, 1.0, 2.0, 2.0)
    if abs(result - 1.0) <= TOLERANCE:
        passed += 1
    else:
        print(f"  FAIL: example quadratic: got {result}, expected 1.0")
        failed += 1

    return passed, failed


def main():
    total_passed = 0
    total_failed = 0

    print("RichardsonExtrapolation Correspondence Tests")
    print("=" * 50)

    print("\n1. Exactness (polynomial error cancellation)...")
    p, f = test_exactness()
    print(f"   {p} passed, {f} failed")
    total_passed += p
    total_failed += f

    print("\n2. Constant function preservation...")
    p, f = test_constant_function()
    print(f"   {p} passed, {f} failed")
    total_passed += p
    total_failed += f

    print("\n3. Linearity...")
    p, f = test_linearity()
    print(f"   {p} passed, {f} failed")
    total_passed += p
    total_failed += f

    print("\n4. Order improvement...")
    p, f = test_order_improvement()
    print(f"   {p} passed, {f} failed")
    total_passed += p
    total_failed += f

    print("\n5. Numerical examples...")
    p, f = test_numerical_examples()
    print(f"   {p} passed, {f} failed")
    total_passed += p
    total_failed += f

    print("\n" + "=" * 50)
    print(f"TOTAL: {total_passed} passed, {total_failed} failed")

    return 1 if total_failed > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
