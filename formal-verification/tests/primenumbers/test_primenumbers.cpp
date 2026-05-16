/*
 * 🔬 Lean Squad — correspondence test for PrimeNumbers
 *
 * Validates C++ PrimeNumbers::get(n) matches nthPrime(n) = Nat.nth Nat.Prime n.
 * Self-contained reimplementation of the trial-division algorithm from
 * ql/math/primenumbers.cpp to avoid Boost dependency.
 *
 * Tests: first 100 primes, spot checks, monotonicity for 1000 values.
 */

#include <iostream>
#include <vector>
#include <cmath>
#include <cstdlib>

// Reimplementation of PrimeNumbers matching ql/math/primenumbers.cpp
class PrimeNumbers {
public:
    static unsigned long get(size_t absoluteIndex) {
        if (primes_.empty()) {
            static const unsigned long firstPrimes[] = {
                2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47
            };
            primes_.assign(firstPrimes, firstPrimes + 15);
        }
        while (primes_.size() <= absoluteIndex)
            nextPrime();
        return primes_[absoluteIndex];
    }
private:
    static void nextPrime() {
        unsigned long p, n, m = primes_.back();
        do {
            m += 2;
            n = static_cast<unsigned long>(std::sqrt(static_cast<double>(m)));
            size_t i = 1;
            do {
                p = primes_[i];
                ++i;
            } while (((m % p) != 0) && p <= n);
        } while (p <= n);
        primes_.push_back(m);
    }
    static std::vector<unsigned long> primes_;
};

std::vector<unsigned long> PrimeNumbers::primes_;

// Ground truth: first 100 primes (matching Lean nthPrime 0..99)
static const unsigned long expected[100] = {
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
    31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
    73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
    127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
    179, 181, 191, 193, 197, 199, 211, 223, 227, 229,
    233, 239, 241, 251, 257, 263, 269, 271, 277, 281,
    283, 293, 307, 311, 313, 317, 331, 337, 347, 349,
    353, 359, 367, 373, 379, 383, 389, 397, 401, 409,
    419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
    467, 479, 487, 491, 499, 503, 509, 521, 523, 541
};

int main() {
    int failures = 0, passed = 0;

    // Test first 100 primes against ground truth
    for (int i = 0; i < 100; ++i) {
        unsigned long result = PrimeNumbers::get(i);
        if (result != expected[i]) {
            std::cerr << "FAIL: get(" << i << ") = " << result
                      << ", expected " << expected[i] << std::endl;
            ++failures;
        } else { ++passed; }
    }

    // Spot checks for larger indices
    struct { size_t idx; unsigned long prime; } spots[] = {
        {167, 997}, {999, 7919}, {1228, 9973}
    };
    for (auto& s : spots) {
        unsigned long r = PrimeNumbers::get(s.idx);
        if (r != s.prime) {
            std::cerr << "FAIL: get(" << s.idx << ") = " << r
                      << ", expected " << s.prime << std::endl;
            ++failures;
        } else { ++passed; }
    }

    // Monotonicity for first 1000 primes
    unsigned long prev = PrimeNumbers::get(0);
    for (size_t i = 1; i < 1000; ++i) {
        unsigned long curr = PrimeNumbers::get(i);
        if (curr <= prev) {
            std::cerr << "FAIL: monotonicity at " << i << std::endl;
            ++failures;
        } else { ++passed; }
        prev = curr;
    }

    std::cout << "PrimeNumbers correspondence: "
              << passed << " passed, " << failures << " failed" << std::endl;
    return failures > 0 ? EXIT_FAILURE : EXIT_SUCCESS;
}
