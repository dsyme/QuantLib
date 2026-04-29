# Formal Verification Research — QuantLib

🔬 *Lean Squad — automated formal verification research for `dsyme/QuantLib`.*

## Last Updated
- **Date**: 2026-04-29 17:05 UTC
- **Commit**: `8acbdd996`

## Repository Overview

**QuantLib** is a comprehensive C++ library for quantitative finance, providing tools for modelling, trading, and risk management. The codebase contains ~2,400 C++ source files covering:

- **Mathematical functions**: interpolations, distributions, numerical methods, optimisers
- **Time/date handling**: day counters, calendars, schedules, date arithmetic
- **Financial instruments**: bonds, options, swaps, and their pricing engines
- **Term structures**: yield curves, volatility surfaces
- **Stochastic processes**: Black-Scholes, Heston, Hull-White

**Primary language**: C++ (no Rust — Aeneas/Charon route is not applicable)

## FV Tool Choice

**Lean 4** with Mathlib. The mathematical nature of QuantLib aligns well with Lean 4's strengths:
- Mathlib has extensive real analysis, algebra, and order theory libraries
- Financial mathematics maps naturally to algebraic properties over ℝ
- Key targets involve pure functions with clear mathematical specs

## Approach

Since QuantLib is C++, we cannot use automatic extraction (Aeneas). Instead:
1. **Manual modelling**: translate C++ functions to Lean 4 functional models
2. **Property verification**: prove algebraic, monotonicity, and round-trip properties
3. **Correspondence validation**: use Route B (executable tests comparing C++ output with Lean `#eval`)

We focus on **pure mathematical functions** where:
- The specification is simpler than the implementation (high FV value)
- Properties are well-defined from finance literature (ISDA standards, textbook formulas)
- The implementation involves non-trivial case analysis or numerical approximation

## Survey Methodology

Targets were identified by:
1. Scanning for pure functions with mathematical correctness criteria
2. Prioritising components where spec complexity << implementation complexity
3. Looking for algebraic round-trip properties, monotonicity, and invariant preservation
4. Checking existing tests for implicit specification hints

## Related Work

- Lean 4 / Mathlib has formalised real analysis including continuous functions, sequences, and limits
- Prior FV work on financial software is sparse; most focuses on smart contracts (Solidity) or protocol verification
- Harrison (2009) formalised floating-point arithmetic in HOL Light — relevant to numerical concerns
- Relevant Mathlib modules: `Mathlib.Analysis.SpecificLimits`, `Mathlib.Data.Real.Basic`, `Mathlib.Order.Monotone`
