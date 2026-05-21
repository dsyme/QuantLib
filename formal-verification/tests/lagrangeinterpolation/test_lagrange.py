#!/usr/bin/env python3
"""
Correspondence tests for Lagrange interpolation (Lean model vs C++ semantics).

🔬 Lean Squad — automated formal verification.

The Lean model in FVSquad/LagrangeInterpolation.lean uses exact rational (ℚ)
arithmetic and implements the second barycentric form of Lagrange interpolation.
This test validates:

1. The rational barycentric model matches the Lean definitions exactly.
2. A floating-point implementation (mirroring the C++ QuantLib code) agrees
   with the exact model within tolerance on all test cases.
3. Key properties (node interpolation, constant exactness, linear exactness,
   scaling invariance) hold on concrete examples.

Route B: executable correspondence tests (C++ codebase, Aeneas not applicable).
"""

from fractions import Fraction
import sys

# ==============================================================================
# Lean model reimplementation (exact rational arithmetic)
# ==============================================================================

def weight_denom(xs, c, i):
    """weightDenom in Lean: Π_{j≠i} c*(x_i - x_j)"""
    prod = Fraction(1)
    for j in range(len(xs)):
        if j != i:
            prod *= c * (xs[i] - xs[j])
    return prod


def bary_weight(xs, c, i):
    """baryWeight in Lean: 1 / weightDenom"""
    wd = weight_denom(xs, c, i)
    assert wd != 0, f"weight_denom is zero at i={i}"
    return Fraction(1) / wd


def scaling_const(xs):
    """scalingConst in Lean: 4 / (x_{n-1} - x_0) if len >= 2, else 1"""
    if len(xs) >= 2:
        return Fraction(4) / (xs[-1] - xs[0])
    return Fraction(1)


def bary_numer(xs, ys, c, x):
    """baryNumer in Lean: Σ_i λ_i/(x - x_i) · y_i"""
    s = Fraction(0)
    for i in range(len(xs)):
        s += bary_weight(xs, c, i) / (x - xs[i]) * ys[i]
    return s


def bary_denom(xs, c, x):
    """baryDenom in Lean: Σ_i λ_i/(x - x_i)"""
    s = Fraction(0)
    for i in range(len(xs)):
        s += bary_weight(xs, c, i) / (x - xs[i])
    return s


def bary_eval(xs, ys, c, x):
    """baryEval in Lean: node check then numer/denom"""
    for i in range(len(xs)):
        if xs[i] == x:
            return ys[i]
    return bary_numer(xs, ys, c, x) / bary_denom(xs, c, x)


def lagrange_classical(xs, ys, x):
    """Classical Lagrange interpolation (reference)."""
    n = len(xs)
    result = Fraction(0)
    for i in range(n):
        basis = Fraction(1)
        for j in range(n):
            if j != i:
                basis *= (x - xs[j]) / (xs[i] - xs[j])
        result += ys[i] * basis
    return result


# ==============================================================================
# C++ model (floating point, mirrors QuantLib implementation)
# ==============================================================================

def cpp_lagrange_eval(xs_f, ys_f, x):
    """Mirrors the C++ _value function from lagrangeinterpolation.hpp."""
    n = len(xs_f)
    # Compute lambda (barycentric weights) as in update()
    c = 4.0 / (xs_f[-1] - xs_f[0])
    lam = [1.0] * n
    for i in range(n):
        for j in range(n):
            if i != j:
                lam[i] *= c * (xs_f[i] - xs_f[j])
        lam[i] = 1.0 / lam[i]

    # Check if x is close to a node
    eps = 10 * 2.220446049250313e-16 * abs(x)
    for i in range(n):
        if abs(x - xs_f[i]) < eps:
            return ys_f[i]

    # Barycentric formula
    numer = 0.0
    denom = 0.0
    for i in range(n):
        alpha = lam[i] / (x - xs_f[i])
        numer += alpha * ys_f[i]
        denom += alpha
    return numer / denom


# ==============================================================================
# Test cases
# ==============================================================================

def test_node_interpolation():
    """Evaluating at a node returns the node's y-value."""
    xs = [Fraction(0), Fraction(1), Fraction(2), Fraction(3)]
    ys = [Fraction(1), Fraction(4), Fraction(9), Fraction(16)]
    c = scaling_const(xs)
    for i in range(len(xs)):
        result = bary_eval(xs, ys, c, xs[i])
        assert result == ys[i], f"Node interpolation failed at i={i}: got {result}"
    print("  PASS: node interpolation (4 cases)")


def test_constant_exactness():
    """If all y_i = k, then p(x) = k for any x."""
    xs = [Fraction(-2), Fraction(0), Fraction(3), Fraction(7)]
    k = Fraction(42)
    ys = [k] * 4
    c = scaling_const(xs)
    test_points = [Fraction(-1), Fraction(1, 2), Fraction(5), Fraction(10)]
    for x in test_points:
        result = bary_eval(xs, ys, c, x)
        assert result == k, f"Constant exactness failed at x={x}: got {result}"
    print("  PASS: constant exactness (4 cases)")


def test_linear_exactness():
    """If y_i = a*x_i + b, then p(x) = a*x + b."""
    xs = [Fraction(-1), Fraction(0), Fraction(1), Fraction(2), Fraction(4)]
    a, b = Fraction(3), Fraction(-7)
    ys = [a * xi + b for xi in xs]
    c = scaling_const(xs)
    test_points = [Fraction(-3), Fraction(1, 3), Fraction(3), Fraction(5)]
    for x in test_points:
        result = bary_eval(xs, ys, c, x)
        expected = a * x + b
        assert result == expected, f"Linear exactness failed at x={x}: got {result}, expected {expected}"
    print("  PASS: linear exactness (4 cases)")


def test_quadratic_exactness():
    """Three nodes determine a unique quadratic; verify it's reproduced."""
    xs = [Fraction(0), Fraction(1), Fraction(2)]
    # y = x^2
    ys = [Fraction(0), Fraction(1), Fraction(4)]
    c = scaling_const(xs)
    test_points = [Fraction(1, 2), Fraction(3, 2), Fraction(-1)]
    for x in test_points:
        result = bary_eval(xs, ys, c, x)
        expected = x * x
        assert result == expected, f"Quadratic exactness failed at x={x}: got {result}, expected {expected}"
    print("  PASS: quadratic exactness (3 cases)")


def test_scaling_invariance():
    """The scaling constant c cancels in the ratio: different c gives same result."""
    xs = [Fraction(0), Fraction(1), Fraction(3), Fraction(5)]
    ys = [Fraction(2), Fraction(-1), Fraction(7), Fraction(3)]
    c1 = Fraction(4) / (xs[-1] - xs[0])  # standard
    c2 = Fraction(1)   # c=1
    c3 = Fraction(100) # c=100
    test_points = [Fraction(2), Fraction(4), Fraction(-1)]
    for x in test_points:
        r1 = bary_numer(xs, ys, c1, x) / bary_denom(xs, c1, x)
        r2 = bary_numer(xs, ys, c2, x) / bary_denom(xs, c2, x)
        r3 = bary_numer(xs, ys, c3, x) / bary_denom(xs, c3, x)
        assert r1 == r2 == r3, f"Scaling invariance failed at x={x}: {r1}, {r2}, {r3}"
    print("  PASS: scaling invariance (3 cases, 3 scales each)")


def test_classical_equivalence():
    """Barycentric form agrees with classical Lagrange form."""
    xs = [Fraction(-2), Fraction(0), Fraction(1), Fraction(4)]
    ys = [Fraction(5), Fraction(-1), Fraction(3), Fraction(2)]
    c = scaling_const(xs)
    test_points = [Fraction(-1), Fraction(1, 2), Fraction(2), Fraction(3)]
    for x in test_points:
        bary_result = bary_eval(xs, ys, c, x)
        classical_result = lagrange_classical(xs, ys, x)
        assert bary_result == classical_result, \
            f"Classical equiv failed at x={x}: bary={bary_result}, classical={classical_result}"
    print("  PASS: classical equivalence (4 cases)")


def test_cpp_correspondence():
    """Floating-point C++ model agrees with exact rational model within tolerance."""
    xs = [Fraction(-2), Fraction(0), Fraction(1), Fraction(3), Fraction(5)]
    ys = [Fraction(4), Fraction(0), Fraction(1), Fraction(9), Fraction(25)]
    xs_f = [float(x) for x in xs]
    ys_f = [float(y) for y in ys]
    c = scaling_const(xs)
    test_points = [Fraction(-1), Fraction(1, 2), Fraction(2), Fraction(4)]
    tol = 1e-12
    for x in test_points:
        exact = float(bary_eval(xs, ys, c, x))
        cpp = cpp_lagrange_eval(xs_f, ys_f, float(x))
        diff = abs(exact - cpp)
        assert diff < tol, f"C++ correspondence failed at x={float(x)}: exact={exact}, cpp={cpp}, diff={diff}"
    print(f"  PASS: C++ correspondence (4 cases, tol={tol})")


def test_weight_denom_nonzero():
    """For distinct nodes, weight denominators are never zero."""
    xs = [Fraction(0), Fraction(1), Fraction(2), Fraction(3), Fraction(4)]
    c = scaling_const(xs)
    for i in range(len(xs)):
        wd = weight_denom(xs, c, i)
        assert wd != 0, f"weight_denom is zero at i={i}"
    print("  PASS: weight_denom nonzero (5 cases)")


# ==============================================================================
# Main
# ==============================================================================

def main():
    print("Lagrange Interpolation — Correspondence Tests")
    print("=" * 55)
    tests = [
        test_node_interpolation,
        test_constant_exactness,
        test_linear_exactness,
        test_quadratic_exactness,
        test_scaling_invariance,
        test_classical_equivalence,
        test_cpp_correspondence,
        test_weight_denom_nonzero,
    ]
    passed = 0
    failed = 0
    for t in tests:
        try:
            t()
            passed += 1
        except AssertionError as e:
            print(f"  FAIL: {t.__name__}: {e}")
            failed += 1
        except Exception as e:
            print(f"  ERROR: {t.__name__}: {e}")
            failed += 1

    print(f"\nResults: {passed} passed, {failed} failed, {passed + failed} total")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
