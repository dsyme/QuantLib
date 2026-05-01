#!/usr/bin/env python3
"""
Bisection solver correspondence tests.
🔬 Lean Squad — automated formal verification.

Compares the Python reference implementation (matching the Lean model in
FVSquad/Bisection.lean) against expected results derived from the C++ QuantLib
bisection solver (ql/math/solvers1d/bisection.hpp).

Both implementations use the same algorithm:
  1. Orient so f > 0 lies at root + dx
  2. Repeatedly halve dx, test midpoint, update root if fMid <= 0
  3. Terminate when |dx| < accuracy or f(mid) == 0

The Lean model uses exact rationals (ℚ); this test uses Python's Fraction for
exact arithmetic, matching the Lean semantics precisely.
"""

from fractions import Fraction
import json
import sys


# ---------------------------------------------------------------------------
# Python reference implementation (mirrors Lean model exactly)
# ---------------------------------------------------------------------------

def orient(f, xMin, xMax):
    """Orient search so f > 0 lies at root + dx."""
    if f(xMin) < 0:
        return {"root": xMin, "dx": xMax - xMin}
    else:
        return {"root": xMax, "dx": xMin - xMax}


def bisect_step(f, s):
    """One bisection step: halve dx, test midpoint."""
    dx2 = s["dx"] / 2
    xMid = s["root"] + dx2
    fMid = f(xMid)
    if fMid <= 0:
        return {"root": xMid, "dx": dx2}
    else:
        return {"root": s["root"], "dx": dx2}


def bisect(f, s, accuracy, fuel):
    """Run bisection with fuel iterations. Returns root or None."""
    for _ in range(fuel):
        s = bisect_step(f, s)
        if abs(s["dx"]) < accuracy:
            return s["root"]
        if f(s["root"] + s["dx"]) == 0:
            return s["root"] + s["dx"]
    return None


def solve(f, xMin, xMax, accuracy, fuel):
    """Full bisection solver."""
    s0 = orient(f, xMin, xMax)
    return bisect(f, s0, accuracy, fuel)


# ---------------------------------------------------------------------------
# C++ reference: simulate C++ double-precision bisection for comparison
# ---------------------------------------------------------------------------

def solve_float(f_float, xMin, xMax, accuracy, max_eval):
    """Float-based bisection matching C++ QuantLib implementation."""
    fxMin = f_float(xMin)
    if fxMin < 0.0:
        dx = xMax - xMin
        root = xMin
    else:
        dx = xMin - xMax
        root = xMax

    evals = 0
    while evals <= max_eval:
        dx /= 2.0
        xMid = root + dx
        fMid = f_float(xMid)
        evals += 1
        if fMid <= 0.0:
            root = xMid
        if abs(dx) < accuracy or fMid == 0.0:
            return root
    return None


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

def make_test_cases():
    """Generate test cases with known roots and properties."""
    cases = []

    # --- Linear functions f(x) = ax + b ---
    for a, b, xmin, xmax in [
        (Fraction(1), Fraction(-1), Fraction(0), Fraction(2)),
        (Fraction(2), Fraction(-3), Fraction(0), Fraction(5)),
        (Fraction(-1), Fraction(2), Fraction(0), Fraction(4)),
        (Fraction(1), Fraction(0), Fraction(-3), Fraction(3)),
        (Fraction(1), Fraction(-5), Fraction(3), Fraction(10)),
        (Fraction(3), Fraction(7), Fraction(-10), Fraction(0)),
    ]:
        f = lambda x, a=a, b=b: a * x + b
        true_root = -b / a
        cases.append({
            "name": f"linear a={a} b={b} [{xmin},{xmax}]",
            "f": f,
            "f_float": lambda x, a=float(a), b=float(b): a * x + b,
            "xmin": xmin, "xmax": xmax,
            "true_root": true_root,
            "accuracy": Fraction(1, 1000),
            "fuel": 100,
        })

    # --- Quadratic f(x) = x^2 - c ---
    for c, xmin, xmax in [
        (Fraction(4), Fraction(0), Fraction(3)),
        (Fraction(9), Fraction(0), Fraction(5)),
        (Fraction(2), Fraction(1), Fraction(2)),
        (Fraction(25), Fraction(0), Fraction(10)),
    ]:
        f = lambda x, c=c: x * x - c
        cases.append({
            "name": f"quadratic x²-{c} [{xmin},{xmax}]",
            "f": f,
            "f_float": lambda x, c=float(c): x * x - c,
            "xmin": xmin, "xmax": xmax,
            "true_root": None,
            "accuracy": Fraction(1, 10000),
            "fuel": 200,
        })

    # --- Cubic f(x) = x^3 - x ---
    for xmin, xmax, expected_near in [
        (Fraction(-2), Fraction(-1, 2), Fraction(-1)),
        (Fraction(-1, 2), Fraction(1, 2), Fraction(0)),
        (Fraction(1, 2), Fraction(2), Fraction(1)),
    ]:
        f = lambda x: x * x * x - x
        cases.append({
            "name": f"cubic x³-x [{xmin},{xmax}] near {expected_near}",
            "f": f,
            "f_float": lambda x: x ** 3 - x,
            "xmin": xmin, "xmax": xmax,
            "true_root": expected_near,
            "accuracy": Fraction(1, 10000),
            "fuel": 200,
        })

    # --- Edge: exact root at midpoint ---
    cases.append({
        "name": "exact zero at midpoint f(x)=x [-1,1]",
        "f": lambda x: x,
        "f_float": lambda x: x,
        "xmin": Fraction(-1), "xmax": Fraction(1),
        "true_root": Fraction(0),
        "accuracy": Fraction(1, 100),
        "fuel": 50,
    })

    # --- Edge: very tight bracket ---
    cases.append({
        "name": "tight bracket around 1/7",
        "f": lambda x: x - Fraction(1, 7),
        "f_float": lambda x: x - 1.0 / 7.0,
        "xmin": Fraction(0), "xmax": Fraction(1),
        "true_root": Fraction(1, 7),
        "accuracy": Fraction(1, 100000),
        "fuel": 200,
    })

    # --- Different accuracies for convergence rate testing ---
    for acc_exp in [1, 2, 4, 8, 12]:
        acc = Fraction(1, 10 ** acc_exp)
        cases.append({
            "name": f"convergence rate test acc=1e-{acc_exp}",
            "f": lambda x: x - Fraction(1, 3),
            "f_float": lambda x: x - 1.0 / 3.0,
            "xmin": Fraction(-1), "xmax": Fraction(1),
            "true_root": Fraction(1, 3),
            "accuracy": acc,
            "fuel": 500,
        })

    # --- Large bracket ---
    cases.append({
        "name": "large bracket [-1000, 1000]",
        "f": lambda x: x - Fraction(42),
        "f_float": lambda x: x - 42.0,
        "xmin": Fraction(-1000), "xmax": Fraction(1000),
        "true_root": Fraction(42),
        "accuracy": Fraction(1, 1000),
        "fuel": 200,
    })

    # --- Orientation test: f(xMin) > 0, f(xMax) < 0 ---
    cases.append({
        "name": "reversed sign orientation f=1-x [0,2]",
        "f": lambda x: Fraction(1) - x,
        "f_float": lambda x: 1.0 - x,
        "xmin": Fraction(0), "xmax": Fraction(2),
        "true_root": Fraction(1),
        "accuracy": Fraction(1, 10000),
        "fuel": 100,
    })

    return cases


def run_tests():
    """Run all correspondence tests."""
    cases = make_test_cases()
    passed = 0
    failed = 0
    results = []

    for i, tc in enumerate(cases):
        f = tc["f"]
        r = solve(f, tc["xmin"], tc["xmax"], tc["accuracy"], tc["fuel"])

        # Also run float version for comparison
        r_float = solve_float(
            tc["f_float"],
            float(tc["xmin"]), float(tc["xmax"]),
            float(tc["accuracy"]), tc["fuel"]
        )

        ok = True
        notes = []

        if r is None:
            ok = False
            notes.append("FAILED: solver returned None (no convergence)")
        else:
            fr = f(r)
            if tc["true_root"] is not None:
                err = abs(r - tc["true_root"])
                if err > tc["accuracy"]:
                    ok = False
                    notes.append(f"FAILED: |root - true_root| = {float(err):.2e} > accuracy {float(tc['accuracy']):.2e}")
                else:
                    notes.append(f"OK: error = {float(err):.2e}")
            else:
                if abs(fr) > tc["accuracy"] * 10:
                    ok = False
                    notes.append(f"FAILED: |f(root)| = {float(abs(fr)):.2e}")
                else:
                    notes.append(f"OK: |f(root)| = {float(abs(fr)):.2e}")

            # Cross-check rational vs float solver agreement
            if r_float is not None:
                diff = abs(float(r) - r_float)
                if diff > float(tc["accuracy"]) * 2:
                    notes.append(f"WARN: rational vs float diff = {diff:.2e}")
                else:
                    notes.append(f"rational≈float (diff={diff:.2e})")

        status = "PASS" if ok else "FAIL"
        if ok:
            passed += 1
        else:
            failed += 1

        result = {
            "case": i + 1,
            "name": tc["name"],
            "status": status,
            "root_rational": str(r) if r else None,
            "root_float": r_float,
            "notes": "; ".join(notes),
        }
        results.append(result)
        print(f"  [{status}] {tc['name']}: {'; '.join(notes)}")

    print(f"\n{'='*60}")
    print(f"TOTAL: {passed + failed} cases, {passed} passed, {failed} failed")
    print(f"{'='*60}")

    with open("results.json", "w") as fp:
        json.dump({"total": passed + failed, "passed": passed, "failed": failed,
                    "cases": results}, fp, indent=2, default=str)

    return failed == 0


if __name__ == "__main__":
    print("Bisection Solver Correspondence Tests")
    print("=" * 60)
    print("Comparing: Python/Fraction (exact rational, matching Lean model)")
    print("Against:   Python/float (matching C++ QuantLib bisection)")
    print("=" * 60)
    success = run_tests()
    sys.exit(0 if success else 1)
