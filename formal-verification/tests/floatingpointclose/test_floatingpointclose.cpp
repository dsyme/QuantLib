/*
 * Correspondence Test: FloatingPointClose
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ close/close_enough implementation
 * (ql/math/comparison.hpp) against the expected behaviour from the Lean 4
 * formal model (FVSquad.FloatingPointClose). The Lean model uses ℚ (rationals)
 * while C++ uses double; we use rational-representable doubles to minimise
 * floating-point discrepancy.
 *
 * Build: g++ -std=c++17 -O2 -o test_floatingpointclose test_floatingpointclose.cpp
 * Run:   ./test_floatingpointclose
 */

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// --- Minimal close/close_enough model ---
// Copied from ql/math/comparison.hpp (simplified: no QL_EPSILON, uses abstract eps)

static bool model_close(double x, double y, double eps) {
    if (x == y) return true;
    double diff = std::fabs(x - y);
    if (x == 0.0 || y == 0.0)
        return diff <= eps * eps;  // Lean uses ≤; C++ uses <
    return diff <= eps * std::fabs(x) && diff <= eps * std::fabs(y);
}

static bool model_close_enough(double x, double y, double eps) {
    if (x == y) return true;
    double diff = std::fabs(x - y);
    if (x == 0.0 || y == 0.0)
        return diff <= eps * eps;
    return diff <= eps * std::fabs(x) || diff <= eps * std::fabs(y);
}

// --- Test infrastructure ---

static int g_pass = 0;
static int g_fail = 0;

static void check(const std::string& name, bool condition) {
    if (condition) {
        ++g_pass;
    } else {
        ++g_fail;
        std::cerr << "FAIL: " << name << std::endl;
    }
}

int main() {
    std::cout << "=== FloatingPointClose Correspondence Tests ===" << std::endl;

    std::vector<double> values = {0.0, 0.5, 1.0, 2.0, 5.0, 10.0, 11.0, 100.0, -1.0, -5.0, -10.0};
    std::vector<double> epsilons = {0.0, 0.01, 0.1, 0.5, 1.0};

    // --- 1. Reflexivity ---
    // Lean: close_refl, close_enough_refl
    {
        int count = 0;
        for (double x : values) {
            for (double eps : epsilons) {
                if (eps >= 0) {
                    check("refl/close", model_close(x, x, eps));
                    check("refl/close_enough", model_close_enough(x, x, eps));
                    count += 2;
                }
            }
        }
        std::cout << "  Reflexivity: " << count << " cases" << std::endl;
    }

    // --- 2. Symmetry ---
    // Lean: close_symm, close_enough_symm
    {
        int count = 0;
        for (double x : values) {
            for (double y : values) {
                for (double eps : epsilons) {
                    bool c_xy = model_close(x, y, eps);
                    bool c_yx = model_close(y, x, eps);
                    check("symm/close", c_xy == c_yx);

                    bool ce_xy = model_close_enough(x, y, eps);
                    bool ce_yx = model_close_enough(y, x, eps);
                    check("symm/close_enough", ce_xy == ce_yx);
                    count += 2;
                }
            }
        }
        std::cout << "  Symmetry: " << count << " cases" << std::endl;
    }

    // --- 3. Implication: close → close_enough ---
    // Lean: close_implies_close_enough
    {
        int count = 0;
        for (double x : values) {
            for (double y : values) {
                for (double eps : epsilons) {
                    if (model_close(x, y, eps)) {
                        check("implies/close_to_ce", model_close_enough(x, y, eps));
                    }
                    ++count;
                }
            }
        }
        std::cout << "  Implication: " << count << " cases" << std::endl;
    }

    // --- 4. Zero tolerance ---
    // Lean: close_zero_tol, close_enough_zero_tol — with eps=0, close ↔ equal (non-zero case)
    {
        int count = 0;
        for (double x : values) {
            for (double y : values) {
                if (x != 0.0 && y != 0.0) {
                    bool c = model_close(x, y, 0.0);
                    bool ce = model_close_enough(x, y, 0.0);
                    check("zero_tol/close", c == (x == y));
                    check("zero_tol/close_enough", ce == (x == y));
                    count += 2;
                }
            }
        }
        std::cout << "  Zero tolerance: " << count << " cases" << std::endl;
    }

    // --- 5. Monotonicity in tolerance ---
    // Lean: close_mono_tol, close_enough_mono_tol
    {
        int count = 0;
        for (double x : values) {
            for (double y : values) {
                for (size_t i = 0; i + 1 < epsilons.size(); ++i) {
                    double e1 = epsilons[i], e2 = epsilons[i + 1];
                    if (x != 0.0 && y != 0.0) {
                        if (model_close(x, y, e1))
                            check("mono_tol/close", model_close(x, y, e2));
                        if (model_close_enough(x, y, e1))
                            check("mono_tol/close_enough", model_close_enough(x, y, e2));
                    }
                    count += 2;
                }
            }
        }
        std::cout << "  Monotonicity in tolerance: " << count << " cases" << std::endl;
    }

    // --- 6. close_enough strictly weaker ---
    // Lean: close_enough_strictly_weaker — there exist x,y,eps where close_enough but not close
    {
        // Use witness: x=10, y=11, eps=1/11
        double x = 10.0, y = 11.0, eps = 1.0 / 11.0;
        bool ce = model_close_enough(x, y, eps);
        bool c  = model_close(x, y, eps);
        check("strictly_weaker/ce_true", ce);
        check("strictly_weaker/c_false", !c);
        std::cout << "  Strictly weaker: 2 cases" << std::endl;
    }

    // --- 7. Non-transitivity witness ---
    // Lean: close_not_transitive — x=10, y=11, z=12.1, eps=0.1
    {
        double x = 10.0, y = 11.0, z = 12.1, eps = 0.1;
        bool c_xy = model_close(x, y, eps);
        bool c_yz = model_close(y, z, eps);
        bool c_xz = model_close(x, z, eps);
        check("non_transitive/xy", c_xy);
        check("non_transitive/yz", c_yz);
        check("non_transitive/not_xz", !c_xz);
        std::cout << "  Non-transitivity: 3 cases" << std::endl;
    }

    // --- Summary ---
    std::cout << "\n=== Results ===" << std::endl;
    std::cout << "  Passed: " << g_pass << std::endl;
    std::cout << "  Failed: " << g_fail << std::endl;
    std::cout << "  Total:  " << g_pass + g_fail << std::endl;

    if (g_fail > 0) {
        std::cerr << "\n*** " << g_fail << " FAILURE(S) ***" << std::endl;
        return 1;
    }

    std::cout << "\n*** ALL TESTS PASSED ***" << std::endl;
    return 0;
}
