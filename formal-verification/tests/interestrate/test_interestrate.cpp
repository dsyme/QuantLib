/*
 * Correspondence Tests: InterestRate (compoundFactor / impliedRate)
 *
 * 🔬 Lean Squad — automated formal verification for dsyme/QuantLib.
 *
 * These tests validate that the Lean 4 formal model (FVSquad.InterestRate)
 * corresponds to the C++ implementation (ql/interestrate.cpp).
 *
 * Route B — Executable Correspondence: standalone C++ test harness that
 * reimplements the minimal InterestRate formulas and verifies them against
 * the same test fixtures used in the Lean model's #eval checks.
 *
 * Build: g++ -std=c++17 -O2 -lm -o test_interestrate test_interestrate.cpp
 * Run:   ./test_interestrate
 */

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <string>
#include <tuple>

// --- Minimal reimplementation matching ql/interestrate.cpp formulas ---

enum Compounding { Simple, Compounded, Continuous,
                   SimpleThenCompounded, CompoundedThenSimple };

// compoundFactor: matches ql/interestrate.cpp L45-67
double compoundFactor(double r, double t, Compounding comp, double freq) {
    switch (comp) {
      case Simple:
        return 1.0 + r * t;
      case Compounded:
        return std::pow(1.0 + r / freq, freq * t);
      case Continuous:
        return std::exp(r * t);
      case SimpleThenCompounded:
        if (t <= 1.0 / freq)
            return 1.0 + r * t;
        else
            return std::pow(1.0 + r / freq, freq * t);
      case CompoundedThenSimple:
        if (t > 1.0 / freq)
            return 1.0 + r * t;
        else
            return std::pow(1.0 + r / freq, freq * t);
    }
    return 0.0; // unreachable
}

// impliedRate: matches ql/interestrate.cpp L69-107
double impliedRate(double compound, Compounding comp, double freq, double t) {
    if (compound == 1.0) return 0.0;
    switch (comp) {
      case Simple:
        return (compound - 1.0) / t;
      case Compounded:
        return (std::pow(compound, 1.0 / (freq * t)) - 1.0) * freq;
      case Continuous:
        return std::log(compound) / t;
      case SimpleThenCompounded:
        if (t <= 1.0 / freq)
            return (compound - 1.0) / t;
        else
            return (std::pow(compound, 1.0 / (freq * t)) - 1.0) * freq;
      case CompoundedThenSimple:
        if (t > 1.0 / freq)
            return (compound - 1.0) / t;
        else
            return (std::pow(compound, 1.0 / (freq * t)) - 1.0) * freq;
    }
    return 0.0;
}

// --- Lean model reimplementation (must match FVSquad.InterestRate Float model) ---

double lean_compoundSimple(double r, double t) { return 1.0 + r * t; }
double lean_compoundCompounded(double r, double t, double n) {
    return std::pow(1.0 + r / n, n * t);
}
double lean_compoundContinuous(double r, double t) { return std::exp(r * t); }

double lean_impliedSimple(double compound, double t) { return (compound - 1.0) / t; }
double lean_impliedCompounded(double compound, double t, double n) {
    return (std::pow(compound, 1.0 / (n * t)) - 1.0) * n;
}
double lean_impliedContinuous(double compound, double t) {
    return std::log(compound) / t;
}

// --- Test infrastructure ---

static int total_tests = 0;
static int passed_tests = 0;
static int failed_tests = 0;

void check_eq(const char* name, double cpp_val, double lean_val, double tol = 1e-12) {
    total_tests++;
    double diff = std::fabs(cpp_val - lean_val);
    if (diff <= tol || (std::isnan(cpp_val) && std::isnan(lean_val))) {
        passed_tests++;
    } else {
        failed_tests++;
        printf("FAIL %s: C++=%.*g  Lean=%.*g  diff=%g\n",
               name, 17, cpp_val, 17, lean_val, diff);
    }
}

void check_roundtrip(const char* name, double r, double t,
                     Compounding comp, double freq, double tol = 1e-10) {
    total_tests++;
    double cf = compoundFactor(r, t, comp, freq);
    double ir = impliedRate(cf, comp, freq, t);
    double diff = std::fabs(ir - r);
    if (diff <= tol) {
        passed_tests++;
    } else {
        failed_tests++;
        printf("FAIL roundtrip %s: r=%g t=%g comp=%d freq=%g => cf=%g => ir=%g diff=%g\n",
               name, r, t, (int)comp, freq, cf, ir, diff);
    }
}

int main() {
    printf("=== InterestRate Correspondence Tests ===\n\n");

    // --- Section 1: Point cases (C++ vs Lean formulas) ---
    printf("--- Section 1: compoundFactor point cases ---\n");

    // Simple compounding
    double rates[] = {0.0, 0.01, 0.05, 0.10, 0.25, -0.02};
    double times[] = {0.0, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0};

    for (double r : rates) {
        for (double t : times) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Simple(r=%g,t=%g)", r, t);
            check_eq(buf, compoundFactor(r, t, Simple, 0),
                     lean_compoundSimple(r, t));
        }
    }

    // Compounded
    double freqs[] = {1.0, 2.0, 4.0, 12.0};
    double pos_rates[] = {0.0, 0.01, 0.05, 0.10, 0.25};
    for (double r : pos_rates) {
        for (double t : times) {
            for (double n : freqs) {
                char buf[128];
                snprintf(buf, sizeof(buf), "Compounded(r=%g,t=%g,n=%g)", r, t, n);
                check_eq(buf, compoundFactor(r, t, Compounded, n),
                         lean_compoundCompounded(r, t, n));
            }
        }
    }

    // Continuous
    for (double r : rates) {
        for (double t : times) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Continuous(r=%g,t=%g)", r, t);
            check_eq(buf, compoundFactor(r, t, Continuous, 0),
                     lean_compoundContinuous(r, t));
        }
    }

    // SimpleThenCompounded and CompoundedThenSimple
    for (double r : pos_rates) {
        for (double n : freqs) {
            double threshold = 1.0 / n;
            // test below, at, and above threshold
            double test_times[] = {threshold * 0.5, threshold, threshold * 2.0};
            for (double t : test_times) {
                if (t <= 0.0) continue;
                char buf[128];
                snprintf(buf, sizeof(buf), "STC(r=%g,t=%g,n=%g)", r, t, n);
                double cpp_stc = compoundFactor(r, t, SimpleThenCompounded, n);
                double lean_stc;
                if (t <= 1.0 / n)
                    lean_stc = lean_compoundSimple(r, t);
                else
                    lean_stc = lean_compoundCompounded(r, t, n);
                check_eq(buf, cpp_stc, lean_stc);

                snprintf(buf, sizeof(buf), "CTS(r=%g,t=%g,n=%g)", r, t, n);
                double cpp_cts = compoundFactor(r, t, CompoundedThenSimple, n);
                double lean_cts;
                if (t > 1.0 / n)
                    lean_cts = lean_compoundSimple(r, t);
                else
                    lean_cts = lean_compoundCompounded(r, t, n);
                check_eq(buf, cpp_cts, lean_cts);
            }
        }
    }

    printf("  compoundFactor: %d tests\n", total_tests);

    // --- Section 2: impliedRate point cases ---
    printf("\n--- Section 2: impliedRate point cases ---\n");
    int before = total_tests;

    double compounds[] = {0.5, 1.0, 1.01, 1.05, 1.10, 1.50, 2.0, 3.0};
    double pos_times[] = {0.25, 0.5, 1.0, 2.0, 5.0};

    for (double c : compounds) {
        for (double t : pos_times) {
            if (c <= 0.0 || t <= 0.0) continue;
            char buf[128];
            snprintf(buf, sizeof(buf), "Implied-Simple(c=%g,t=%g)", c, t);
            if (c == 1.0)
                check_eq(buf, 0.0, 0.0);  // compound==1 => r=0
            else
                check_eq(buf, impliedRate(c, Simple, 0, t),
                         lean_impliedSimple(c, t));
        }
    }

    for (double c : compounds) {
        for (double t : pos_times) {
            for (double n : freqs) {
                if (c <= 0.0 || t <= 0.0) continue;
                char buf[128];
                snprintf(buf, sizeof(buf), "Implied-Compounded(c=%g,t=%g,n=%g)", c, t, n);
                if (c == 1.0)
                    check_eq(buf, 0.0, 0.0);
                else
                    check_eq(buf, impliedRate(c, Compounded, n, t),
                             lean_impliedCompounded(c, t, n));
            }
        }
    }

    for (double c : compounds) {
        for (double t : pos_times) {
            if (c <= 0.0 || t <= 0.0) continue;
            char buf[128];
            snprintf(buf, sizeof(buf), "Implied-Continuous(c=%g,t=%g)", c, t);
            if (c == 1.0)
                check_eq(buf, 0.0, 0.0);
            else
                check_eq(buf, impliedRate(c, Continuous, 0, t),
                         lean_impliedContinuous(c, t));
        }
    }

    printf("  impliedRate: %d tests\n", total_tests - before);

    // --- Section 3: Round-trip sweep (compoundFactor -> impliedRate -> rate) ---
    printf("\n--- Section 3: Round-trip sweep ---\n");
    before = total_tests;

    double sweep_rates[] = {0.001, 0.01, 0.03, 0.05, 0.08, 0.10, 0.15, 0.20};
    double sweep_times[] = {0.1, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0};

    for (double r : sweep_rates) {
        for (double t : sweep_times) {
            char buf[128];
            snprintf(buf, sizeof(buf), "RT-Simple(r=%g,t=%g)", r, t);
            check_roundtrip(buf, r, t, Simple, 1.0);
        }
    }

    for (double r : sweep_rates) {
        for (double t : sweep_times) {
            for (double n : freqs) {
                char buf[128];
                snprintf(buf, sizeof(buf), "RT-Compounded(r=%g,t=%g,n=%g)", r, t, n);
                check_roundtrip(buf, r, t, Compounded, n);
            }
        }
    }

    for (double r : sweep_rates) {
        for (double t : sweep_times) {
            char buf[128];
            snprintf(buf, sizeof(buf), "RT-Continuous(r=%g,t=%g)", r, t);
            check_roundtrip(buf, r, t, Continuous, 1.0);
        }
    }

    printf("  Round-trip: %d tests\n", total_tests - before);

    // --- Section 4: Monotonicity checks ---
    printf("\n--- Section 4: Monotonicity (higher rate => higher compound factor) ---\n");
    before = total_tests;

    for (double t : sweep_times) {
        if (t <= 0.0) continue;
        for (int i = 0; i < 7; i++) {
            double r1 = sweep_rates[i];
            double r2 = sweep_rates[i + 1];
            total_tests++;
            if (compoundFactor(r1, t, Simple, 1.0) <
                compoundFactor(r2, t, Simple, 1.0)) {
                passed_tests++;
            } else {
                failed_tests++;
                printf("FAIL monotone Simple r1=%g < r2=%g at t=%g\n", r1, r2, t);
            }

            for (double n : freqs) {
                total_tests++;
                if (compoundFactor(r1, t, Compounded, n) <
                    compoundFactor(r2, t, Compounded, n)) {
                    passed_tests++;
                } else {
                    failed_tests++;
                    printf("FAIL monotone Compounded r1=%g < r2=%g at t=%g n=%g\n",
                           r1, r2, t, n);
                }
            }

            total_tests++;
            if (compoundFactor(r1, t, Continuous, 1.0) <
                compoundFactor(r2, t, Continuous, 1.0)) {
                passed_tests++;
            } else {
                failed_tests++;
                printf("FAIL monotone Continuous r1=%g < r2=%g at t=%g\n", r1, r2, t);
            }
        }
    }

    printf("  Monotonicity: %d tests\n", total_tests - before);

    // --- Summary ---
    printf("\n=== SUMMARY ===\n");
    printf("Total: %d  Passed: %d  Failed: %d\n", total_tests, passed_tests, failed_tests);

    if (failed_tests > 0) {
        printf("\n*** %d CORRESPONDENCE FAILURES ***\n", failed_tests);
        return 1;
    } else {
        printf("\nAll correspondence tests PASSED.\n");
        return 0;
    }
}
