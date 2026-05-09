/*
 * Correspondence Test: Quadratic Formula
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ quadratic class implementation
 * against expected values from the Lean 4 formal model (FVSquad.Quadratic).
 * It verifies that eval, turningPoint, discriminant, and roots compute
 * identical results on a shared set of test fixtures.
 *
 * Build: g++ -std=c++17 -o test_quadratic test_quadratic.cpp
 * Run:   ./test_quadratic
 *
 * The test reimplements minimal quadratic logic copied directly from
 * ql/math/quadratic.hpp/cpp to keep the harness self-contained.
 */

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// --- Minimal quadratic model (copied from ql/math/quadratic.cpp) ---

class quadratic {
public:
    quadratic(double a, double b, double c) : a_(a), b_(b), c_(c) {}

    double turningPoint() const { return -b_ / (2.0 * a_); }

    double valueAtTurningPoint() const { return (*this)(turningPoint()); }

    double operator()(double x) const { return x * (x * a_ + b_) + c_; }

    double discriminant() const { return b_ * b_ - 4 * a_ * c_; }

    bool roots(double& x, double& y) const {
        double d = discriminant();
        if (d < 0) {
            x = y = turningPoint();
            return false;
        }
        d = std::sqrt(d);
        x = (-b_ - d) / (2 * a_);
        y = (-b_ + d) / (2 * a_);
        return true;
    }

private:
    double a_, b_, c_;
};

// --- Test infrastructure ---

static int tests_run = 0;
static int tests_passed = 0;
static int tests_failed = 0;

static void check(const std::string& name, double actual, double expected, double tol = 1e-12) {
    tests_run++;
    if (std::abs(actual - expected) <= tol) {
        tests_passed++;
    } else {
        tests_failed++;
        std::cerr << "FAIL: " << name
                  << " — expected " << expected
                  << ", got " << actual
                  << " (diff=" << std::abs(actual - expected) << ")\n";
    }
}

static void check_bool(const std::string& name, bool actual, bool expected) {
    tests_run++;
    if (actual == expected) {
        tests_passed++;
    } else {
        tests_failed++;
        std::cerr << "FAIL: " << name
                  << " — expected " << (expected ? "true" : "false")
                  << ", got " << (actual ? "true" : "false") << "\n";
    }
}

// --- Correspondence tests ---
// Each test verifies a property proved in FVSquad.Quadratic.lean

void test_eval_zero() {
    // eval q 0 = q.c (theorem eval_zero)
    struct { double a, b, c; } cases[] = {
        {1, 2, 3}, {-1, 0, 5}, {2, -3, 0}, {0.5, 1.5, -2.5}, {100, -200, 300}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        check("eval_zero(a=" + std::to_string(tc.a) + ")", q(0.0), tc.c);
    }
}

void test_eval_one() {
    // eval q 1 = a + b + c (theorem eval_one)
    struct { double a, b, c; } cases[] = {
        {1, 2, 3}, {-1, 0, 5}, {2, -3, 0}, {0.5, 1.5, -2.5}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        check("eval_one(a=" + std::to_string(tc.a) + ")", q(1.0), tc.a + tc.b + tc.c);
    }
}

void test_eval_horner() {
    // eval q x = x*(x*a + b) + c (theorem eval_eq_horner)
    struct { double a, b, c, x; } cases[] = {
        {1, -5, 6, 2}, {1, -5, 6, 3}, {2, 0, -8, 2}, {1, 0, 0, 7}, {-3, 12, -9, 1}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        double horner = tc.x * (tc.x * tc.a + tc.b) + tc.c;
        check("eval_horner(x=" + std::to_string(tc.x) + ")", q(tc.x), horner);
    }
}

void test_turning_point() {
    // turningPoint q = -b/(2a) (definition)
    // formalDeriv at turningPoint = 0 (theorem formalDeriv_at_turningPoint_zero)
    struct { double a, b, c; } cases[] = {
        {1, -6, 9}, {2, 4, 1}, {-1, 2, 3}, {0.5, -3, 4}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        double expected_tp = -tc.b / (2.0 * tc.a);
        check("turningPoint(a=" + std::to_string(tc.a) + ")", q.turningPoint(), expected_tp);
        // Derivative at turning point should be ~0: 2*a*tp + b
        double deriv = 2 * tc.a * q.turningPoint() + tc.b;
        check("deriv_at_tp(a=" + std::to_string(tc.a) + ")", deriv, 0.0, 1e-10);
    }
}

void test_valueAtTurningPoint() {
    // valueAtTurningPoint q = c - b²/(4a) (theorem valueAtTurningPoint_formula)
    struct { double a, b, c; } cases[] = {
        {1, -6, 9}, {2, 4, 1}, {-1, 2, 3}, {1, 0, -4}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        double expected = tc.c - tc.b * tc.b / (4.0 * tc.a);
        check("valAtTP(a=" + std::to_string(tc.a) + ")", q.valueAtTurningPoint(), expected);
    }
}

void test_discriminant() {
    // discriminant q = b² - 4ac (definition)
    struct { double a, b, c, expected; } cases[] = {
        {1, -5, 6, 1},     // two real roots
        {1, -6, 9, 0},     // double root
        {1, 0, 1, -4},     // no real roots
        {2, -3, -2, 25},   // two real roots
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        check("discriminant(a=" + std::to_string(tc.a) + ")", q.discriminant(), tc.expected);
    }
}

void test_roots_are_zeros() {
    // eval_rootLarge_eq_zero and eval_rootSmall_eq_zero
    struct { double a, b, c; } cases[] = {
        {1, -5, 6}, {1, -6, 9}, {2, -3, -2}, {1, 0, -4}, {-1, 3, -2}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        if (q.discriminant() >= 0) {
            double x, y;
            q.roots(x, y);
            check("rootSmall_is_zero(a=" + std::to_string(tc.a) + ")", q(x), 0.0, 1e-10);
            check("rootLarge_is_zero(a=" + std::to_string(tc.a) + ")", q(y), 0.0, 1e-10);
        }
    }
}

void test_vieta_sum() {
    // vieta_sum: rootSmall + rootLarge = -b/a
    struct { double a, b, c; } cases[] = {
        {1, -5, 6}, {2, -3, -2}, {1, 0, -4}, {-1, 3, -2}, {1, -6, 9}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        if (q.discriminant() >= 0) {
            double x, y;
            q.roots(x, y);
            check("vieta_sum(a=" + std::to_string(tc.a) + ")", x + y, -tc.b / tc.a, 1e-10);
        }
    }
}

void test_vieta_product() {
    // vieta_product: rootSmall * rootLarge = c/a
    struct { double a, b, c; } cases[] = {
        {1, -5, 6}, {2, -3, -2}, {1, 0, -4}, {-1, 3, -2}, {1, -6, 9}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        if (q.discriminant() >= 0) {
            double x, y;
            q.roots(x, y);
            check("vieta_product(a=" + std::to_string(tc.a) + ")", x * y, tc.c / tc.a, 1e-10);
        }
    }
}

void test_double_root() {
    // double_root: when Δ = 0, both roots equal turning point
    struct { double a, b, c; } cases[] = {
        {1, -6, 9}, {1, 2, 1}, {4, -4, 1}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        if (std::abs(q.discriminant()) < 1e-12) {
            double x, y;
            q.roots(x, y);
            check("double_root_small(a=" + std::to_string(tc.a) + ")", x, q.turningPoint(), 1e-10);
            check("double_root_large(a=" + std::to_string(tc.a) + ")", y, q.turningPoint(), 1e-10);
        }
    }
}

void test_no_real_roots() {
    // root_implies_discriminant_nonneg (contrapositive: Δ < 0 → no real roots)
    struct { double a, b, c; } cases[] = {
        {1, 0, 1}, {1, 1, 1}, {2, 0, 3}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        double x, y;
        bool has_roots = q.roots(x, y);
        check_bool("no_real_roots(a=" + std::to_string(tc.a) + ")", has_roots, false);
    }
}

void test_eval_symmetry() {
    // eval_sym: eval(x) + eval(-x) = 2*(a*x² + c)
    struct { double a, b, c, x; } cases[] = {
        {1, -5, 6, 3}, {2, 0, -8, 1}, {-1, 3, -2, 2}, {0.5, 1.5, -2.5, 4}
    };
    for (auto& tc : cases) {
        quadratic q(tc.a, tc.b, tc.c);
        double lhs = q(tc.x) + q(-tc.x);
        double rhs = 2.0 * (tc.a * tc.x * tc.x + tc.c);
        check("eval_sym(x=" + std::to_string(tc.x) + ")", lhs, rhs);
    }
}

int main() {
    test_eval_zero();
    test_eval_one();
    test_eval_horner();
    test_turning_point();
    test_valueAtTurningPoint();
    test_discriminant();
    test_roots_are_zeros();
    test_vieta_sum();
    test_vieta_product();
    test_double_root();
    test_no_real_roots();
    test_eval_symmetry();

    std::cout << "\n=== Quadratic Correspondence Tests ===\n"
              << "Total: " << tests_run
              << "  Passed: " << tests_passed
              << "  Failed: " << tests_failed << "\n";

    return tests_failed > 0 ? 1 : 0;
}
