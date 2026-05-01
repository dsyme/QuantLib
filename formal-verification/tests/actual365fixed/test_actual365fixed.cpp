/*
 * Correspondence Test: Actual365Fixed Day Counter (Standard Convention)
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ Actual365Fixed Standard logic
 * against the expected values from the Lean 4 formal model
 * (FVSquad.Actual365Fixed). It verifies that the Lean model and the
 * C++ implementation compute identical results on a shared set of fixtures.
 *
 * Build: g++ -std=c++17 -O2 -o test_actual365fixed test_actual365fixed.cpp
 * Run:   ./test_actual365fixed
 *
 * The test does NOT link against QuantLib — it reimplements the minimal
 * Actual365Fixed Standard logic to keep the harness self-contained.
 * The reimplemented logic is a direct copy from ql/time/daycounters/actual365fixed.hpp.
 */

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// --- Minimal Actual365Fixed Standard model ---
// dayCount(d1, d2) = d2 - d1
// yearFraction(d1, d2) = dayCount(d1, d2) / 365.0

static long dayCount(long d1, long d2) {
    return d2 - d1;
}

static double yearFraction(long d1, long d2) {
    return static_cast<double>(dayCount(d1, d2)) / 365.0;
}

// --- Test infrastructure ---

struct TestCase {
    std::string name;
    long d1;
    long d2;
    long expectedDayCount;
    double expectedYearFraction;
};

static int g_pass = 0;
static int g_fail = 0;

static void check(const std::string& name, bool cond) {
    if (cond) {
        g_pass++;
    } else {
        g_fail++;
        std::cerr << "FAIL: " << name << std::endl;
    }
}

static void checkDouble(const std::string& name, double actual, double expected) {
    if (actual == expected || std::fabs(actual - expected) < 1e-15) {
        g_pass++;
    } else {
        g_fail++;
        std::cerr << "FAIL: " << name
                  << " (expected=" << expected << ", actual=" << actual << ")" << std::endl;
    }
}

int main() {
    // ======================================================================
    // Section 1: Point cases (matching Lean #eval examples)
    // ======================================================================

    std::vector<TestCase> cases = {
        // Basic cases matching Lean #eval
        {"365 days",     0, 365, 365, 1.0},
        {"182 days",     0, 182, 182, 182.0/365.0},
        {"same date",    0,   0,   0, 0.0},
        {"1 day",        0,   1,   1, 1.0/365.0},
        {"90 days",      0,  90,  90, 90.0/365.0},
        {"180 days",     0, 180, 180, 180.0/365.0},
        {"730 days",     0, 730, 730, 2.0},
        // Negative (d1 > d2)
        {"negative",   365,   0, -365, -1.0},
        // Offset dates
        {"offset 100",  100, 465, 365, 1.0},
        {"offset 1000", 1000, 1365, 365, 1.0},
        // Leap year span (366 days)
        {"366 days",     0, 366, 366, 366.0/365.0},
    };

    std::cout << "=== Section 1: Point cases ===" << std::endl;
    for (const auto& tc : cases) {
        long dc = dayCount(tc.d1, tc.d2);
        double yf = yearFraction(tc.d1, tc.d2);
        check(tc.name + " dayCount", dc == tc.expectedDayCount);
        checkDouble(tc.name + " yearFraction", yf, tc.expectedYearFraction);
    }
    std::cout << "Point cases done." << std::endl;

    // ======================================================================
    // Section 2: Additivity sweep — dayCount(d1,d2) + dayCount(d2,d3) = dayCount(d1,d3)
    // Corresponds to: theorem dayCount_additive
    // ======================================================================

    std::cout << "=== Section 2: Additivity sweep ===" << std::endl;
    int additivity_count = 0;
    for (long d1 = -50; d1 <= 50; d1 += 10) {
        for (long d2 = -50; d2 <= 50; d2 += 10) {
            for (long d3 = -50; d3 <= 50; d3 += 10) {
                long lhs = dayCount(d1, d2) + dayCount(d2, d3);
                long rhs = dayCount(d1, d3);
                check("additivity", lhs == rhs);
                additivity_count++;
            }
        }
    }
    std::cout << "Additivity: " << additivity_count << " cases." << std::endl;

    // ======================================================================
    // Section 3: Antisymmetry sweep — dayCount(d1,d2) = -dayCount(d2,d1)
    // Corresponds to: theorem dayCount_antisymm
    // ======================================================================

    std::cout << "=== Section 3: Antisymmetry sweep ===" << std::endl;
    int antisymm_count = 0;
    for (long d1 = -100; d1 <= 100; d1 += 10) {
        for (long d2 = -100; d2 <= 100; d2 += 10) {
            check("antisymmetry", dayCount(d1, d2) == -dayCount(d2, d1));
            antisymm_count++;
        }
    }
    std::cout << "Antisymmetry: " << antisymm_count << " cases." << std::endl;

    // ======================================================================
    // Section 4: Translation invariance — dayCount(d1+k, d2+k) = dayCount(d1, d2)
    // Corresponds to: theorem dayCount_translate
    // ======================================================================

    std::cout << "=== Section 4: Translation invariance ===" << std::endl;
    int translate_count = 0;
    for (long d1 = -50; d1 <= 50; d1 += 25) {
        for (long d2 = -50; d2 <= 50; d2 += 25) {
            for (long k = -100; k <= 100; k += 50) {
                check("translation", dayCount(d1 + k, d2 + k) == dayCount(d1, d2));
                translate_count++;
            }
        }
    }
    std::cout << "Translation: " << translate_count << " cases." << std::endl;

    // ======================================================================
    // Section 5: Full year — dayCount(d, d+365) = 365
    // Corresponds to: theorem dayCount_full_year
    // ======================================================================

    std::cout << "=== Section 5: Full year ===" << std::endl;
    int fullyear_count = 0;
    for (long d = -500; d <= 500; d += 10) {
        check("full_year", dayCount(d, d + 365) == 365);
        fullyear_count++;
    }
    std::cout << "Full year: " << fullyear_count << " cases." << std::endl;

    // ======================================================================
    // Section 6: Monotonicity — d2 < d3 → dayCount(d1,d2) < dayCount(d1,d3)
    // Corresponds to: theorem dayCount_strict_mono
    // ======================================================================

    std::cout << "=== Section 6: Strict monotonicity ===" << std::endl;
    int mono_count = 0;
    for (long d1 = -50; d1 <= 50; d1 += 25) {
        for (long d2 = -50; d2 <= 50; d2 += 10) {
            for (long d3 = d2 + 1; d3 <= 50; d3 += 10) {
                check("monotonicity", dayCount(d1, d2) < dayCount(d1, d3));
                mono_count++;
            }
        }
    }
    std::cout << "Monotonicity: " << mono_count << " cases." << std::endl;

    // ======================================================================
    // Summary
    // ======================================================================

    int total = g_pass + g_fail;
    std::cout << "\n=== RESULTS ===" << std::endl;
    std::cout << "Total:  " << total << std::endl;
    std::cout << "Passed: " << g_pass << std::endl;
    std::cout << "Failed: " << g_fail << std::endl;

    if (g_fail == 0) {
        std::cout << "ALL " << g_pass << " TESTS PASSED ✅" << std::endl;
    } else {
        std::cout << "SOME TESTS FAILED ❌" << std::endl;
    }

    return (g_fail == 0) ? 0 : 1;
}
