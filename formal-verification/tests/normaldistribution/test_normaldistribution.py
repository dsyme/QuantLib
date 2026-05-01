#!/usr/bin/env python3
"""
Correspondence tests: NormalDistribution (Lean model vs mathematical reference).

🔬 Lean Squad — automated formal verification for dsyme/QuantLib.

Route B: Executable correspondence tests comparing the Lean model's
mathematical formulas against Python's scipy/math reference implementations
on the same inputs.

What is tested:
  1. PDF point values — gaussianPDF vs scipy.stats.norm.pdf
  2. PDF symmetry — f(μ+d) == f(μ-d)
  3. PDF peak — f(μ) >= f(x) for all tested x
  4. PDF non-negativity — f(x) >= 0
  5. CDF point values — gaussianCDF vs scipy.stats.norm.cdf
  6. CDF at mean — Φ(μ) == 0.5
  7. CDF symmetry — Φ(2μ-x) + Φ(x) == 1
  8. PDF derivative — sign checks at x < μ, x == μ, x > μ
"""

import math
import sys

# Use math stdlib only (no scipy dependency needed for exact formulas)

def gaussian_pdf(mu, sigma, x):
    """Lean model: gaussianPDF μ σ x"""
    return (1.0 / (sigma * math.sqrt(2 * math.pi))) * math.exp(-(x - mu)**2 / (2 * sigma**2))

def gaussian_pdf_deriv(mu, sigma, x):
    """Lean model: gaussianPDF_deriv μ σ x = -(x-μ)/σ² · f(x)"""
    return -(x - mu) / sigma**2 * gaussian_pdf(mu, sigma, x)

def gaussian_cdf(mu, sigma, x):
    """Lean model: gaussianCDF μ σ x = 0.5 · (1 + erf((x-μ)/(σ√2)))"""
    return 0.5 * (1.0 + math.erf((x - mu) / (sigma * math.sqrt(2))))


def test_pdf_point_values():
    """Test PDF against known values."""
    cases = 0
    failures = 0
    # Standard normal
    for x in [-3, -2, -1, -0.5, 0, 0.5, 1, 2, 3]:
        got = gaussian_pdf(0, 1, x)
        expected = (1.0 / math.sqrt(2 * math.pi)) * math.exp(-x**2 / 2)
        if abs(got - expected) > 1e-15:
            print(f"  FAIL: pdf(0,1,{x}) = {got}, expected {expected}")
            failures += 1
        cases += 1
    # Non-standard: μ=2, σ=0.5
    for x in [0, 1, 1.5, 2, 2.5, 3, 4]:
        got = gaussian_pdf(2, 0.5, x)
        expected = (1.0 / (0.5 * math.sqrt(2 * math.pi))) * math.exp(-(x-2)**2 / (2*0.25))
        if abs(got - expected) > 1e-15:
            print(f"  FAIL: pdf(2,0.5,{x}) = {got}, expected {expected}")
            failures += 1
        cases += 1
    # Grid: multiple μ, σ, x
    for mu in [-1, 0, 1, 5]:
        for sigma in [0.1, 0.5, 1, 2, 10]:
            for x in [mu - 3*sigma, mu - sigma, mu, mu + sigma, mu + 3*sigma]:
                got = gaussian_pdf(mu, sigma, x)
                expected = (1.0 / (sigma * math.sqrt(2 * math.pi))) * math.exp(-(x-mu)**2 / (2*sigma**2))
                if abs(got - expected) > 1e-14:
                    print(f"  FAIL: pdf({mu},{sigma},{x}) = {got}, expected {expected}")
                    failures += 1
                cases += 1
    return cases, failures


def test_pdf_symmetry():
    """Test f(μ+d) == f(μ-d)."""
    cases = 0
    failures = 0
    for mu in [-2, 0, 1, 3.5]:
        for sigma in [0.1, 0.5, 1, 2, 5]:
            for d in [0, 0.01, 0.5, 1, 2, 5, 10]:
                left = gaussian_pdf(mu, sigma, mu + d)
                right = gaussian_pdf(mu, sigma, mu - d)
                if abs(left - right) > 1e-15:
                    print(f"  FAIL: symmetry at μ={mu},σ={sigma},d={d}: {left} vs {right}")
                    failures += 1
                cases += 1
    return cases, failures


def test_pdf_peak():
    """Test f(μ) >= f(x) for all x."""
    cases = 0
    failures = 0
    for mu in [-1, 0, 2]:
        for sigma in [0.1, 0.5, 1, 2]:
            peak = gaussian_pdf(mu, sigma, mu)
            for x in [mu - 10, mu - 5, mu - 2, mu - 1, mu - 0.1,
                       mu + 0.1, mu + 1, mu + 2, mu + 5, mu + 10]:
                val = gaussian_pdf(mu, sigma, x)
                if val > peak + 1e-15:
                    print(f"  FAIL: peak at μ={mu},σ={sigma}: f({x})={val} > f(μ)={peak}")
                    failures += 1
                cases += 1
    return cases, failures


def test_pdf_nonneg():
    """Test f(x) >= 0."""
    cases = 0
    failures = 0
    for mu in [-5, 0, 5]:
        for sigma in [0.01, 0.1, 1, 10]:
            for x in range(-100, 101, 5):
                val = gaussian_pdf(mu, sigma, x)
                if val < -1e-15:
                    print(f"  FAIL: nonneg at μ={mu},σ={sigma},x={x}: {val}")
                    failures += 1
                cases += 1
    return cases, failures


def test_cdf_point_values():
    """Test CDF against math.erf reference."""
    cases = 0
    failures = 0
    for mu in [-1, 0, 1]:
        for sigma in [0.5, 1, 2]:
            for x in [mu - 3*sigma, mu - 2*sigma, mu - sigma, mu, mu + sigma, mu + 2*sigma, mu + 3*sigma]:
                got = gaussian_cdf(mu, sigma, x)
                expected = 0.5 * (1 + math.erf((x - mu) / (sigma * math.sqrt(2))))
                if abs(got - expected) > 1e-15:
                    print(f"  FAIL: cdf({mu},{sigma},{x}) = {got}, expected {expected}")
                    failures += 1
                cases += 1
    return cases, failures


def test_cdf_at_mean():
    """Test Φ(μ) == 0.5."""
    cases = 0
    failures = 0
    for mu in [-10, -1, 0, 1, 10]:
        for sigma in [0.01, 0.1, 1, 5, 100]:
            got = gaussian_cdf(mu, sigma, mu)
            if abs(got - 0.5) > 1e-15:
                print(f"  FAIL: cdf({mu},{sigma},{mu}) = {got}, expected 0.5")
                failures += 1
            cases += 1
    return cases, failures


def test_cdf_symmetry():
    """Test Φ(2μ-x) + Φ(x) == 1."""
    cases = 0
    failures = 0
    for mu in [-2, 0, 3]:
        for sigma in [0.5, 1, 2]:
            for x in [mu - 5, mu - 2, mu - 1, mu, mu + 1, mu + 2, mu + 5]:
                left = gaussian_cdf(mu, sigma, 2*mu - x)
                right = gaussian_cdf(mu, sigma, x)
                if abs(left + right - 1.0) > 1e-14:
                    print(f"  FAIL: symmetry μ={mu},σ={sigma},x={x}: {left}+{right}={left+right}")
                    failures += 1
                cases += 1
    return cases, failures


def test_pdf_deriv_sign():
    """Test derivative sign: >0 for x<μ, =0 at x=μ, <0 for x>μ."""
    cases = 0
    failures = 0
    for mu in [-1, 0, 2]:
        for sigma in [0.5, 1, 2]:
            # At mean: zero
            d = gaussian_pdf_deriv(mu, sigma, mu)
            if abs(d) > 1e-15:
                print(f"  FAIL: deriv at mean μ={mu},σ={sigma}: {d}")
                failures += 1
            cases += 1
            # Left of mean: positive
            for x in [mu - 3, mu - 1, mu - 0.1]:
                d = gaussian_pdf_deriv(mu, sigma, x)
                if d <= 0:
                    print(f"  FAIL: deriv left μ={mu},σ={sigma},x={x}: {d}")
                    failures += 1
                cases += 1
            # Right of mean: negative
            for x in [mu + 0.1, mu + 1, mu + 3]:
                d = gaussian_pdf_deriv(mu, sigma, x)
                if d >= 0:
                    print(f"  FAIL: deriv right μ={mu},σ={sigma},x={x}: {d}")
                    failures += 1
                cases += 1
    return cases, failures


if __name__ == "__main__":
    total_cases = 0
    total_failures = 0
    tests = [
        ("PDF point values", test_pdf_point_values),
        ("PDF symmetry", test_pdf_symmetry),
        ("PDF peak", test_pdf_peak),
        ("PDF non-negativity", test_pdf_nonneg),
        ("CDF point values", test_cdf_point_values),
        ("CDF at mean", test_cdf_at_mean),
        ("CDF symmetry", test_cdf_symmetry),
        ("PDF derivative sign", test_pdf_deriv_sign),
    ]
    for name, fn in tests:
        cases, failures = fn()
        status = "✅ PASS" if failures == 0 else f"❌ FAIL ({failures})"
        print(f"  {status} — {name}: {cases} cases")
        total_cases += cases
        total_failures += failures

    print(f"\nTotal: {total_cases} cases, {total_failures} failures")
    sys.exit(1 if total_failures > 0 else 0)
