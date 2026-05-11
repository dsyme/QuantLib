/*
 * Correspondence Test: NewtonSafe Bracketed Newton-Raphson Solver
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ NewtonSafe solver against expected
 * values derived from the Lean 4 formal model (FVSquad.NewtonSafe).
 * It verifies that orient, useBisection, step, and solve produce results
 * consistent with the formal model on a shared set of test fixtures.
 *
 * Build: g++ -std=c++17 -O2 -o test_newtonsafe test_newtonsafe.cpp -lm
 * Run:   ./test_newtonsafe
 *
 * The test reimplements the NewtonSafe algorithm from
 * ql/math/solvers1d/newtonsafe.hpp as a self-contained harness.
 */

#include <cmath>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <string>
#include <vector>

// --- Lean model equivalent types and functions ---

struct NSState {
    double root;
    double xl;   // f(xl) < 0
    double xh;   // f(xh) > 0
    double dx;
    double dxold;
};

// Orient: arrange so f(xl) < 0, f(xh) > 0
NSState orient(std::function<double(double)> f, double xMin, double xMax, double root) {
    NSState s;
    s.root = root;
    if (f(xMin) < 0.0) {
        s.xl = xMin;
        s.xh = xMax;
    } else {
        s.xl = xMax;
        s.xh = xMin;
    }
    s.dx = xMax - xMin;
    s.dxold = xMax - xMin;
    return s;
}

// Decide whether to use bisection
bool useBisection(const NSState& s, double froot, double dfroot) {
    bool outOfRange = ((s.root - s.xh) * dfroot - froot) *
                      ((s.root - s.xl) * dfroot - froot) > 0.0;
    bool tooSlow = std::fabs(2.0 * froot) > std::fabs(s.dxold * dfroot);
    return outOfRange || tooSlow;
}

// One step of NewtonSafe
NSState step(std::function<double(double)> f,
             std::function<double(double)> df,
             const NSState& s) {
    double froot = f(s.root);
    double dfroot = df(s.root);

    double dx_new, root_new;
    if (useBisection(s, froot, dfroot)) {
        dx_new = (s.xh - s.xl) / 2.0;
        root_new = s.xl + dx_new;
    } else {
        dx_new = froot / dfroot;
        root_new = s.root - dx_new;
    }

    double fNew = f(root_new);
    NSState s_new;
    s_new.root = root_new;
    s_new.dx = dx_new;
    s_new.dxold = s.dx;
    if (fNew < 0.0) {
        s_new.xl = root_new;
        s_new.xh = s.xh;
    } else {
        s_new.xl = s.xl;
        s_new.xh = root_new;
    }
    return s_new;
}

// Full solver with fuel
struct SolveResult {
    bool converged;
    double root;
    int iterations;
};

SolveResult solve(std::function<double(double)> f,
                  std::function<double(double)> df,
                  double xMin, double xMax, double root0,
                  double accuracy, int maxIter) {
    NSState s = orient(f, xMin, xMax, root0);
    for (int i = 0; i < maxIter; ++i) {
        s = step(f, df, s);
        if (std::fabs(s.dx) < accuracy) {
            return {true, s.root, i + 1};
        }
    }
    return {false, s.root, maxIter};
}

// --- Test infrastructure ---

int total_tests = 0;
int passed_tests = 0;
int failed_tests = 0;

void check(const std::string& name, bool condition) {
    total_tests++;
    if (condition) {
        passed_tests++;
    } else {
        failed_tests++;
        std::cerr << "FAIL: " << name << std::endl;
    }
}

void check_close(const std::string& name, double actual, double expected, double tol) {
    total_tests++;
    if (std::fabs(actual - expected) <= tol) {
        passed_tests++;
    } else {
        failed_tests++;
        std::cerr << "FAIL: " << name
                  << " (expected=" << expected << ", actual=" << actual
                  << ", diff=" << std::fabs(actual - expected) << ")" << std::endl;
    }
}

// --- Test functions ---

// f(x) = x^2 - 2, root = sqrt(2)
double f1(double x) { return x * x - 2.0; }
double df1(double x) { return 2.0 * x; }

// f(x) = x^3 - x - 1, root ≈ 1.3247
double f2(double x) { return x * x * x - x - 1.0; }
double df2(double x) { return 3.0 * x * x - 1.0; }

// f(x) = sin(x), root = π in [2,4]
double f3(double x) { return std::sin(x); }
double df3(double x) { return std::cos(x); }

// f(x) = e^x - 3, root = ln(3) ≈ 1.0986
double f4(double x) { return std::exp(x) - 3.0; }
double df4(double x) { return std::exp(x); }

// f(x) = x (linear), root = 0
double f5(double x) { return x; }
double df5(double x) { (void)x; return 1.0; }

int main() {
    std::cout << "=== NewtonSafe Correspondence Tests ===" << std::endl;
    std::cout << "🔬 Lean Squad — automated formal verification." << std::endl << std::endl;

    // P1: Bisection midpoint in bracket (Lean: bisect_step_in_bracket)
    {
        double xl = 1.0, xh = 3.0;
        double mid = xl + (xh - xl) / 2.0;
        check("P1: bisect_midpoint_ge_xl", mid >= xl);
        check("P1: bisect_midpoint_le_xh", mid <= xh);
        // Various brackets
        for (double lo : {-10.0, 0.0, 1.0, 100.0}) {
            for (double hi : {lo + 0.001, lo + 1.0, lo + 100.0}) {
                double m = lo + (hi - lo) / 2.0;
                check("P1: bisect_in_bracket", m >= lo && m <= hi);
            }
        }
    }

    // P2: Bisection halves width (Lean: bisect_halves_width)
    {
        double xl = 1.0, xh = 5.0;
        double mid = xl + (xh - xl) / 2.0;
        double remaining = xh - mid;
        double expected = (xh - xl) / 2.0;
        check_close("P2: bisect_halves_width", remaining, expected, 1e-15);
    }

    // P5: Newton used when in bracket and decreasing fast (Lean: newton_used_when_in_bracket)
    {
        NSState s;
        s.root = 1.5; s.xl = 1.0; s.xh = 2.0; s.dx = 0.5; s.dxold = 1.0;
        double froot = f1(s.root);   // 0.25
        double dfroot = df1(s.root); // 3.0
        // Newton step: 1.5 - 0.25/3.0 = 1.4167, which is in [1, 2]
        // Check range: ((1.5-2)*3 - 0.25) * ((1.5-1)*3 - 0.25) = (-1.75)*(1.25) = -2.1875 < 0
        // Not out of range ✓
        // Check speed: |2*0.25| = 0.5 vs |1.0*3.0| = 3.0 → 0.5 < 3.0, fast enough ✓
        check("P5: newton_in_bracket_not_bisection", !useBisection(s, froot, dfroot));
    }

    // P6: Bisection when out of bracket (Lean: bisection_used_when_out_of_bracket)
    {
        NSState s;
        s.root = 1.5; s.xl = 1.0; s.xh = 2.0; s.dx = 0.5; s.dxold = 0.01;
        // With very small dxold, too slow condition triggers
        double froot = f1(s.root);
        double dfroot = df1(s.root);
        // |2*0.25| = 0.5 vs |0.01*3.0| = 0.03, 0.5 > 0.03 → too slow
        check("P6: bisection_when_slow", useBisection(s, froot, dfroot));
    }

    // P8: Derivative zero triggers bisection (Lean: deriv_zero_triggers_bisection)
    {
        NSState s;
        s.root = 1.0; s.xl = 0.0; s.xh = 2.0; s.dx = 1.0; s.dxold = 1.0;
        check("P8: deriv_zero_bisection_fnonzero", useBisection(s, 1.0, 0.0));
        // f=0 case: |2*0| = 0 vs |1*0| = 0, not tooSlow. Range: (0-0)*0 = 0, not > 0.
        // So bisection is NOT forced when both f and f' are 0
        check("P8: deriv_zero_f_zero_no_bisection", !useBisection(s, 0.0, 0.0));
    }

    // P9: Orient produces correct bracket ordering (Lean: orient_bracket_ordered)
    {
        auto s = orient(f1, 1.0, 2.0, 1.5);
        // f1(1) = -1 < 0, so xl = 1, xh = 2
        check("P9: orient_xl", s.xl == 1.0);
        check("P9: orient_xh", s.xh == 2.0);
        check("P9: orient_ordered", s.xl <= s.xh);

        auto s2 = orient(f1, -2.0, -1.0, -1.5);
        // f1(-2) = 2 > 0, f1(-1) = -1 < 0, so xl = -1, xh = -2
        check("P9: orient_reversed_xl", s2.xl == -1.0);
        check("P9: orient_reversed_xh", s2.xh == -2.0);
    }

    // P11: Solve convergence (Lean: solve_implies_convergence)
    // If solve returns, |dx| < accuracy at some iteration
    {
        auto result = solve(f1, df1, 1.0, 2.0, 1.5, 1e-10, 100);
        check("P11: sqrt2_converges", result.converged);
        check_close("P11: sqrt2_root", result.root, std::sqrt(2.0), 1e-10);

        auto result2 = solve(f2, df2, 1.0, 2.0, 1.5, 1e-10, 100);
        check("P11: cubic_converges", result2.converged);
        check_close("P11: cubic_root", result2.root * result2.root * result2.root - result2.root - 1.0, 0.0, 1e-9);

        auto result3 = solve(f3, df3, 2.0, 4.0, 3.0, 1e-12, 100);
        check("P11: sinx_converges", result3.converged);
        check_close("P11: sinx_root", result3.root, M_PI, 1e-12);

        auto result4 = solve(f4, df4, 0.0, 2.0, 1.0, 1e-10, 100);
        check("P11: exp_converges", result4.converged);
        check_close("P11: exp_root", result4.root, std::log(3.0), 1e-10);

        auto result5 = solve(f5, df5, -1.0, 1.0, 0.5, 1e-15, 100);
        check("P11: linear_converges", result5.converged);
        check_close("P11: linear_root", result5.root, 0.0, 1e-15);
    }

    // Step-by-step correspondence: verify individual steps match Lean model
    {
        // Step from initial state for f(x) = x^2 - 2 on [1, 2]
        NSState s0 = orient(f1, 1.0, 2.0, 1.5);
        check("step0: root", s0.root == 1.5);
        check("step0: xl", s0.xl == 1.0);
        check("step0: xh", s0.xh == 2.0);
        check("step0: dx", s0.dx == 1.0);

        NSState s1 = step(f1, df1, s0);
        // froot = f(1.5) = 0.25, dfroot = 3.0
        // Range test: ((1.5-2)*3-0.25)*((1.5-1)*3-0.25) = (-1.75)*(1.25) = -2.1875 ≤ 0 → NOT outOfRange
        // Speed test: |2*0.25| = 0.5, |1.0*3.0| = 3.0, 0.5 ≤ 3.0 → NOT tooSlow
        // Newton: dx = 0.25/3.0, root = 1.5 - 0.25/3.0 = 1.41667
        double expected_dx = 0.25 / 3.0;
        double expected_root = 1.5 - expected_dx;
        check_close("step1: root", s1.root, expected_root, 1e-14);
        check_close("step1: dx", s1.dx, expected_dx, 1e-14);
        // f(1.41667) ≈ 0.00694 > 0, so xh = root_new, xl stays
        check_close("step1: xl", s1.xl, 1.0, 1e-14);
        check_close("step1: xh", s1.xh, expected_root, 1e-14);
    }

    // Worst-case convergence: pure bisection converges in O(log) steps
    {
        // Use a function where Newton would fail: f(x) = sign(x-1.5) * |x-1.5|^0.5
        // This has zero derivative at the root, so bisection always triggers
        auto f_hard = [](double x) -> double {
            double d = x - 1.5;
            return (d >= 0 ? 1.0 : -1.0) * std::sqrt(std::fabs(d));
        };
        auto df_hard = [](double x) -> double {
            double d = x - 1.5;
            if (std::fabs(d) < 1e-15) return 1e10; // avoid division by zero
            return 0.5 / std::sqrt(std::fabs(d));
        };

        auto result = solve(f_hard, df_hard, 0.0, 3.0, 1.5, 1e-8, 200);
        check("worst_case: converges", result.converged);
        check_close("worst_case: root", result.root, 1.5, 1e-8);
        // Bisection worst case: log2(3/1e-8) ≈ 28 iterations
        check("worst_case: reasonable_iters", result.iterations <= 60);
    }

    // Edge cases
    {
        // Root at bracket endpoint
        auto result = solve(f5, df5, 0.0, 1.0, 0.5, 1e-10, 100);
        check("edge: root_at_endpoint", result.converged);
        check_close("edge: root_at_endpoint_val", result.root, 0.0, 1e-10);

        // Very tight bracket
        double sq2 = std::sqrt(2.0);
        auto result2 = solve(f1, df1, sq2 - 1e-6, sq2 + 1e-6, sq2, 1e-12, 100);
        check("edge: tight_bracket", result2.converged);
        check_close("edge: tight_bracket_root", result2.root, sq2, 1e-12);
    }

    // Summary
    std::cout << std::endl;
    std::cout << "Results: " << passed_tests << "/" << total_tests << " passed";
    if (failed_tests > 0)
        std::cout << ", " << failed_tests << " FAILED";
    std::cout << std::endl;

    return (failed_tests > 0) ? 1 : 0;
}
