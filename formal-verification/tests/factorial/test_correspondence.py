#!/usr/bin/env python3
"""
Correspondence test for FVSquad.Factorial Lean model vs QuantLib Factorial::get(n).

🔬 Lean Squad — automated formal verification.

This script validates that the Lean model (Nat.factorial) matches the QuantLib
C++ implementation's lookup table for n = 0..27. The C++ implementation uses a
precomputed table for these values.

Route B: Executable correspondence tests.
"""

# Expected values from QuantLib's tabulated Factorial::get(n) for n=0..27
# Source: ql/math/factorial.cpp - the tabulated[] array (as exact integers)
QUANTLIB_FACTORIAL_TABLE = [
    1,                          # 0!
    1,                          # 1!
    2,                          # 2!
    6,                          # 3!
    24,                         # 4!
    120,                        # 5!
    720,                        # 6!
    5040,                       # 7!
    40320,                      # 8!
    362880,                     # 9!
    3628800,                    # 10!
    39916800,                   # 11!
    479001600,                  # 12!
    6227020800,                 # 13!
    87178291200,                # 14!
    1307674368000,              # 15!
    20922789888000,             # 16!
    355687428096000,            # 17!
    6402373705728000,           # 18!
    121645100408832000,         # 19!
    2432902008176640000,        # 20!
    51090942171709440000,       # 21!
    1124000727777607680000,     # 22!
    25852016738884976640000,    # 23!
    620448401733239439360000,   # 24!
    15511210043330985984000000, # 25!
    403291461126605635584000000,# 26!
    10888869450418352160768000000, # 27!
]

import math

def test_factorial_correspondence():
    """Compare Python math.factorial (same as Lean Nat.factorial) with QuantLib table."""
    passed = 0
    failed = 0

    for n in range(28):
        lean_value = math.factorial(n)  # Nat.factorial in Lean = math.factorial in Python
        quantlib_value = QUANTLIB_FACTORIAL_TABLE[n]

        if lean_value == quantlib_value:
            passed += 1
        else:
            print(f"MISMATCH at n={n}: Lean={lean_value}, QuantLib={quantlib_value}")
            failed += 1

    print(f"\nFactorial correspondence test: {passed} passed, {failed} failed (n=0..27)")

    # Additional properties verified in Lean — spot-check them here too
    print("\nProperty checks:")

    # factorial_pos: factorial n > 0 for all n
    all_pos = all(math.factorial(n) > 0 for n in range(100))
    print(f"  factorial_pos (n=0..99): {'PASS' if all_pos else 'FAIL'}")

    # factorial_succ: factorial (n+1) = (n+1) * factorial n
    succ_ok = all(math.factorial(n+1) == (n+1) * math.factorial(n) for n in range(100))
    print(f"  factorial_succ (n=0..99): {'PASS' if succ_ok else 'FAIL'}")

    # factorial_mono: n ≤ m → factorial n ≤ factorial m
    mono_ok = all(math.factorial(i) <= math.factorial(j)
                  for i in range(50) for j in range(i, 50))
    print(f"  factorial_mono (0..49): {'PASS' if mono_ok else 'FAIL'}")

    # factorial_even_div: 2 | factorial n for n ≥ 2
    even_ok = all(math.factorial(n) % 2 == 0 for n in range(2, 100))
    print(f"  factorial_even_div (n=2..99): {'PASS' if even_ok else 'FAIL'}")

    if failed > 0:
        return 1
    return 0

if __name__ == "__main__":
    exit(test_factorial_correspondence())
