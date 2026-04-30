# Thirty360 European Correspondence Tests

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Overview

This harness validates that the Lean implementation model in `FVSquad/Thirty360.lean`
agrees with the QuantLib C++ `Thirty360::EU_Impl::dayCount` function.

## How It Works

The Python script mirrors the Lean definitions:
- `adjust_day_eu(d)` = `if d >= 31 then 30 else d` (equivalent to `if d == 31 then 30 else d` for valid dates ≤ 31)
- `day_count_eu(d1, d2)` = `360*(Y2-Y1) + 30*(M2-M1) + (adjust(D2) - adjust(D1))`

## Running

```bash
python3 test_thirty360.py
```

## Coverage

- **32 value tests**: same-date, single-day, month boundaries, year boundaries, multi-year, day-31 capping, leap year dates, quarters, cross-year
- **543 property tests**: antisymmetry (32 cases), same-date-zero (480 date combinations), adjust idempotency (31 values)
- **Total: 575 test cases**

## Correspondence Level

**Exact** for valid date inputs (day ∈ [1, 31]). The Lean model uses `d >= 31` which is equivalent to the C++ `d == 31` when days are at most 31. The formula `360*(Y2-Y1) + 30*(M2-M1) + (D2'-D1')` is identical in both implementations.

## Source Reference

- C++ implementation: `ql/time/daycounters/thirty360.cpp` → `Thirty360::EU_Impl::dayCount`
- Lean model: `formal-verification/lean/FVSquad/Thirty360.lean` → `FVSquad.Thirty360.dayCountEU`
