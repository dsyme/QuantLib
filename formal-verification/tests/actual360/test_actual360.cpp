/*
 * Correspondence Test: Actual360 Day Counter
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ Actual360 day counter implementation
 * against the expected values from the Lean 4 formal model. It verifies that
 * the Lean model (FVSquad.Actual360) and the C++ implementation compute
 * identical results on a shared set of test fixtures.
 *
 * Build: g++ -std=c++17 -o test_actual360 test_actual360.cpp
 * Run:   ./test_actual360
 *
 * The test does NOT link against QuantLib — it reimplements the minimal
 * Actual360 logic to keep the harness self-contained and buildable anywhere.
 * The reimplemented logic is a direct copy from ql/time/daycounters/actual360.hpp.
 */

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// --- Minimal Actual360 model (copied from ql/time/daycounters/actual360.hpp) ---
// dayCount(d1, d2, includeLastDay) = (d2 - d1) + (includeLastDay ? 1 : 0)
// yearFraction(d1, d2, includeLastDay) = dayCount(d1, d2, includeLastDay) / 360.0

static long dayCount(long d1, long d2, bool includeLastDay) {
    return (d2 - d1) + (includeLastDay ? 1 : 0);
}

static double yearFraction(long d1, long d2, bool includeLastDay) {
    return static_cast<double>(dayCount(d1, d2, includeLastDay)) / 360.0;
}

// --- Test infrastructure ---

struct TestCase {
    std::string name;
    long d1;
    long d2;
    bool includeLastDay;
    long expectedDayCount;
    double expectedYearFraction;
};

int main() {
    // These test cases match the Lean #eval examples and the informal spec.
    // Dates are represented as integer day offsets (matching the Lean Int model).
    std::vector<TestCase> cases = {
        // Basic cases
        {"182 days, no incl",       0, 182, false, 182, 182.0/360.0},
        {"182 days, incl",          0, 182, true,  183, 183.0/360.0},
        {"360 days, no incl",       0, 360, false, 360, 1.0},
        {"360 days, incl",          0, 360, true,  361, 361.0/360.0},

        // Same date
        {"same date, no incl",      0, 0, false, 0, 0.0},
        {"same date, incl",         0, 0, true,  1, 1.0/360.0},

        // One day
        {"one day, no incl",        0, 1, false, 1, 1.0/360.0},
        {"one day, incl",           0, 1, true,  2, 2.0/360.0},

        // Negative (d2 < d1)
        {"negative, no incl",       10, 5, false, -5, -5.0/360.0},
        {"negative, incl",          10, 5, true,  -4, -4.0/360.0},

        // Large values
        {"full year 365, no incl",  0, 365, false, 365, 365.0/360.0},
        {"two years, no incl",      0, 730, false, 730, 730.0/360.0},

        // Additivity check: dayCount(0,100) + dayCount(100,250) == dayCount(0,250)
        {"additivity seg1",         0, 100, false, 100, 100.0/360.0},
        {"additivity seg2",         100, 250, false, 150, 150.0/360.0},
        {"additivity total",        0, 250, false, 250, 250.0/360.0},

        // Antisymmetry: dayCount(a,b) = -dayCount(b,a)
        {"antisymm forward",        20, 50, false, 30, 30.0/360.0},
        {"antisymm backward",       50, 20, false, -30, -30.0/360.0},

        // Arbitrary offsets
        {"offset 1000-1182",        1000, 1182, false, 182, 182.0/360.0},
        {"offset negative start",   -100, 100, false, 200, 200.0/360.0},
    };

    int passed = 0;
    int failed = 0;

    for (const auto& tc : cases) {
        long dc = dayCount(tc.d1, tc.d2, tc.includeLastDay);
        double yf = yearFraction(tc.d1, tc.d2, tc.includeLastDay);

        bool dcOk = (dc == tc.expectedDayCount);
        bool yfOk = (std::abs(yf - tc.expectedYearFraction) < 1e-15);

        if (dcOk && yfOk) {
            passed++;
        } else {
            failed++;
            std::cerr << "FAIL: " << tc.name
                      << " | dayCount: got " << dc << " expected " << tc.expectedDayCount
                      << " | yearFraction: got " << yf << " expected " << tc.expectedYearFraction
                      << std::endl;
        }
    }

    std::cout << "Actual360 correspondence tests: "
              << passed << " passed, " << failed << " failed, "
              << cases.size() << " total" << std::endl;

    // Verify additivity property: dayCount(d1,d2) + dayCount(d2,d3) == dayCount(d1,d3)
    // for a sweep of values (without includeLastDay)
    int additivity_pass = 0;
    int additivity_fail = 0;
    for (long d1 = -50; d1 <= 50; d1 += 10) {
        for (long d2 = -50; d2 <= 50; d2 += 10) {
            for (long d3 = -50; d3 <= 50; d3 += 10) {
                long lhs = dayCount(d1, d2, false) + dayCount(d2, d3, false);
                long rhs = dayCount(d1, d3, false);
                if (lhs == rhs) {
                    additivity_pass++;
                } else {
                    additivity_fail++;
                    if (additivity_fail <= 3) {
                        std::cerr << "ADDITIVITY FAIL: d1=" << d1 << " d2=" << d2
                                  << " d3=" << d3 << " lhs=" << lhs << " rhs=" << rhs << std::endl;
                    }
                }
            }
        }
    }
    std::cout << "Additivity sweep: " << additivity_pass << " passed, "
              << additivity_fail << " failed" << std::endl;

    // Verify antisymmetry: dayCount(a,b) == -dayCount(b,a) (without includeLastDay)
    int antisymm_pass = 0;
    int antisymm_fail = 0;
    for (long a = -100; a <= 100; a += 7) {
        for (long b = -100; b <= 100; b += 7) {
            if (dayCount(a, b, false) == -dayCount(b, a, false)) {
                antisymm_pass++;
            } else {
                antisymm_fail++;
            }
        }
    }
    std::cout << "Antisymmetry sweep: " << antisymm_pass << " passed, "
              << antisymm_fail << " failed" << std::endl;

    // Verify includeLastDay off-by-one: dayCount(d1,d2,true) + dayCount(d2,d3,true) == dayCount(d1,d3,true) + 1
    int offbyone_pass = 0;
    int offbyone_fail = 0;
    for (long d1 = -20; d1 <= 20; d1 += 5) {
        for (long d2 = -20; d2 <= 20; d2 += 5) {
            for (long d3 = -20; d3 <= 20; d3 += 5) {
                long lhs = dayCount(d1, d2, true) + dayCount(d2, d3, true);
                long rhs = dayCount(d1, d3, true) + 1;
                if (lhs == rhs) {
                    offbyone_pass++;
                } else {
                    offbyone_fail++;
                }
            }
        }
    }
    std::cout << "IncludeLastDay off-by-one sweep: " << offbyone_pass << " passed, "
              << offbyone_fail << " failed" << std::endl;

    bool allOk = (failed == 0 && additivity_fail == 0
                  && antisymm_fail == 0 && offbyone_fail == 0);
    std::cout << (allOk ? "ALL PASSED" : "SOME FAILURES") << std::endl;
    return allOk ? 0 : 1;
}
