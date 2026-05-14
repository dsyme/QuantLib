/*
 * Correspondence Test: PlainVanillaPayoff
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * This standalone test compares the C++ PlainVanillaPayoff implementation
 * against the expected values from the Lean 4 formal model. It verifies that
 * the Lean model (FVSquad.PlainVanillaPayoff) and the C++ implementation
 * compute identical results on a shared set of test fixtures.
 *
 * Build: g++ -std=c++17 -O2 -o test_plainvanillapayoff test_plainvanillapayoff.cpp
 * Run:   ./test_plainvanillapayoff
 *
 * The test does NOT link against QuantLib — it reimplements the minimal
 * PlainVanillaPayoff logic to keep the harness self-contained and buildable
 * anywhere. The reimplemented logic is a direct copy from
 * ql/instruments/payoffs.cpp lines 91-99.
 */

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

// --- Minimal PlainVanillaPayoff model ---
// Copied from ql/instruments/payoffs.cpp:91-99
// Call: max(price - strike, 0.0)
// Put:  max(strike - price, 0.0)

enum class OptionType { Call, Put };

static double payoff(OptionType type, double strike, double price) {
    switch (type) {
        case OptionType::Call:
            return std::max(price - strike, 0.0);
        case OptionType::Put:
            return std::max(strike - price, 0.0);
    }
    return 0.0; // unreachable
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

static void check_eq(const std::string& name, double actual, double expected,
                      double tol = 1e-15) {
    bool ok = std::abs(actual - expected) <= tol;
    if (!ok) {
        std::cerr << "FAIL: " << name << " — got " << actual
                  << ", expected " << expected << std::endl;
    }
    check(name, ok);
}

int main() {
    std::cout << "=== PlainVanillaPayoff Correspondence Tests ===" << std::endl;

    // --- 1. Point cases: specific strike/price pairs ---
    // These match the Lean model's definition:
    //   payoff Call K S = max(S - K, 0)
    //   payoff Put  K S = max(K - S, 0)

    struct PointCase {
        std::string name;
        OptionType type;
        double strike;
        double price;
        double expected;
    };

    std::vector<PointCase> pointCases = {
        // ATM
        {"call_atm_100",   OptionType::Call, 100.0, 100.0,  0.0},
        {"put_atm_100",    OptionType::Put,  100.0, 100.0,  0.0},
        // ITM call
        {"call_itm_110",   OptionType::Call, 100.0, 110.0, 10.0},
        {"call_itm_200",   OptionType::Call, 100.0, 200.0, 100.0},
        // OTM call
        {"call_otm_90",    OptionType::Call, 100.0,  90.0,  0.0},
        {"call_otm_0",     OptionType::Call, 100.0,   0.0,  0.0},
        // ITM put
        {"put_itm_90",     OptionType::Put,  100.0,  90.0, 10.0},
        {"put_itm_0",      OptionType::Put,  100.0,   0.0, 100.0},
        // OTM put
        {"put_otm_110",    OptionType::Put,  100.0, 110.0,  0.0},
        {"put_otm_200",    OptionType::Put,  100.0, 200.0,  0.0},
        // Zero strike
        {"call_K0_S50",    OptionType::Call,   0.0,  50.0, 50.0},
        {"put_K0_S50",     OptionType::Put,    0.0,  50.0,  0.0},
        // Zero price
        {"call_S0_K50",    OptionType::Call,  50.0,   0.0,  0.0},
        {"put_S0_K50",     OptionType::Put,   50.0,   0.0, 50.0},
        // Both zero
        {"call_K0_S0",     OptionType::Call,   0.0,   0.0,  0.0},
        {"put_K0_S0",      OptionType::Put,    0.0,   0.0,  0.0},
        // Small values
        {"call_small",     OptionType::Call,   0.01,  0.02, 0.01},
        {"put_small",      OptionType::Put,    0.02,  0.01, 0.01},
        // Large values
        {"call_large",     OptionType::Call, 1e6, 1.5e6, 5e5},
        {"put_large",      OptionType::Put,  1.5e6, 1e6, 5e5},
    };

    for (const auto& tc : pointCases) {
        double result = payoff(tc.type, tc.strike, tc.price);
        check_eq("point/" + tc.name, result, tc.expected);
    }

    // --- 2. Non-negativity sweep ---
    // Lean theorem: payoff_nonneg — payoff is always ≥ 0
    {
        int count = 0;
        std::vector<double> strikes = {0, 0.01, 1, 10, 50, 100, 500, 1000, 1e6};
        std::vector<double> prices  = {0, 0.01, 1, 10, 50, 100, 500, 1000, 1e6};
        for (double K : strikes) {
            for (double S : prices) {
                double c = payoff(OptionType::Call, K, S);
                double p = payoff(OptionType::Put, K, S);
                check("nonneg/call_K" + std::to_string(K) + "_S" + std::to_string(S),
                      c >= 0.0);
                check("nonneg/put_K" + std::to_string(K) + "_S" + std::to_string(S),
                      p >= 0.0);
                count += 2;
            }
        }
        std::cout << "  Non-negativity: " << count << " cases" << std::endl;
    }

    // --- 3. Put-call parity sweep ---
    // Lean theorem: put_call_parity — call(S) - put(S) = S - K
    {
        int count = 0;
        std::vector<double> strikes = {0, 1, 10, 50, 100, 200, 500, 1000};
        std::vector<double> prices  = {0, 1, 10, 50, 100, 200, 500, 1000};
        for (double K : strikes) {
            for (double S : prices) {
                double c = payoff(OptionType::Call, K, S);
                double p = payoff(OptionType::Put, K, S);
                double lhs = c - p;
                double rhs = S - K;
                check_eq("parity/K" + std::to_string(K) + "_S" + std::to_string(S),
                         lhs, rhs);
                ++count;
            }
        }
        std::cout << "  Put-call parity: " << count << " cases" << std::endl;
    }

    // --- 4. Monotonicity sweep ---
    // Lean theorems: call_mono, put_antimono
    {
        int count = 0;
        std::vector<double> strikes = {0, 50, 100, 200};
        std::vector<double> prices  = {0, 10, 50, 100, 150, 200, 500};
        for (double K : strikes) {
            for (size_t i = 0; i + 1 < prices.size(); ++i) {
                double S1 = prices[i], S2 = prices[i + 1];
                // call is non-decreasing in S
                check("mono/call_K" + std::to_string(K),
                      payoff(OptionType::Call, K, S1) <=
                      payoff(OptionType::Call, K, S2));
                // put is non-increasing in S
                check("mono/put_K" + std::to_string(K),
                      payoff(OptionType::Put, K, S2) <=
                      payoff(OptionType::Put, K, S1));
                count += 2;
            }
        }
        std::cout << "  Monotonicity: " << count << " cases" << std::endl;
    }

    // --- 5. Symmetry sweep ---
    // Lean theorem: call_put_symmetry — call(K, S) = put(S, K)
    {
        int count = 0;
        std::vector<double> vals = {0, 1, 10, 50, 100, 200, 500};
        for (double K : vals) {
            for (double S : vals) {
                double c = payoff(OptionType::Call, K, S);
                double p = payoff(OptionType::Put, S, K);
                check_eq("symmetry/K" + std::to_string(K) + "_S" + std::to_string(S),
                         c, p);
                ++count;
            }
        }
        std::cout << "  Symmetry: " << count << " cases" << std::endl;
    }

    // --- 6. Convexity sweep ---
    // Lean theorems: call_convex, put_convex
    // payoff(K, t*S1 + (1-t)*S2) <= t*payoff(K,S1) + (1-t)*payoff(K,S2)
    {
        int count = 0;
        std::vector<double> strikes = {50, 100, 200};
        std::vector<double> s1_vals = {0, 50, 100, 200};
        std::vector<double> s2_vals = {0, 50, 100, 200};
        std::vector<double> t_vals  = {0.0, 0.25, 0.5, 0.75, 1.0};
        for (double K : strikes) {
            for (double S1 : s1_vals) {
                for (double S2 : s2_vals) {
                    for (double t : t_vals) {
                        double Smix = t * S1 + (1.0 - t) * S2;
                        // Call convexity
                        double lhs_c = payoff(OptionType::Call, K, Smix);
                        double rhs_c = t * payoff(OptionType::Call, K, S1)
                                      + (1.0 - t) * payoff(OptionType::Call, K, S2);
                        check("convex/call", lhs_c <= rhs_c + 1e-12);
                        // Put convexity
                        double lhs_p = payoff(OptionType::Put, K, Smix);
                        double rhs_p = t * payoff(OptionType::Put, K, S1)
                                      + (1.0 - t) * payoff(OptionType::Put, K, S2);
                        check("convex/put", lhs_p <= rhs_p + 1e-12);
                        count += 2;
                    }
                }
            }
        }
        std::cout << "  Convexity: " << count << " cases" << std::endl;
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
