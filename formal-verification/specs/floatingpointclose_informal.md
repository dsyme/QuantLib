# Informal Specification: FloatingPointClose

🔬 *Lean Squad — automated formal verification for dsyme/QuantLib.*

## Source

- **File**: `ql/math/comparison.hpp`
- **Functions**: `close(x, y)`, `close(x, y, n)`, `close_enough(x, y)`, `close_enough(x, y, n)`

## Purpose

Provides floating-point comparison functions following Knuth's advice for approximate
equality. Two variants exist:

- **`close`**: strict closeness — `|x - y| ≤ ε|x|` **AND** `|x - y| ≤ ε|y|` (both bounds must hold).
- **`close_enough`**: relaxed closeness — `|x - y| ≤ ε|x|` **OR** `|x - y| ≤ ε|y|` (either bound suffices).

where `ε = n × QL_EPSILON` and `QL_EPSILON = std::numeric_limits<double>::epsilon()` (≈ 2.22e-16).

The default multiplier is `n = 42`.

## Preconditions

- `x`, `y`: any `Real` (double). Including ±∞ and ±0.
- `n`: a non-negative `Size` (unsigned integer). `n = 0` makes tolerance = 0, so `close(x, y, 0)` ≡ `x == y`.

## Postconditions

### `close(x, y, n)`

Returns `true` if and only if one of:

1. `x == y` (bitwise equality — handles ±∞, same-sign zeros), **or**
2. Neither `x` nor `y` is zero, and `|x - y| ≤ n·ε·|x|` **and** `|x - y| ≤ n·ε·|y|`, **or**
3. At least one of `x`, `y` is zero, and `|x - y| < (n·ε)²`.

### `close_enough(x, y, n)`

Returns `true` if and only if one of:

1. `x == y` (bitwise equality), **or**
2. Neither `x` nor `y` is zero, and `|x - y| ≤ n·ε·|x|` **or** `|x - y| ≤ n·ε·|y|`, **or**
3. At least one of `x`, `y` is zero, and `|x - y| < (n·ε)²`.

### Key difference

`close` requires **both** relative bounds (AND). `close_enough` requires **either** (OR).
Therefore: `close(x, y, n) → close_enough(x, y, n)` always.

## Invariants / Properties

### 1. Reflexivity
- `close(x, x, n) = true` for all `x`, `n`
- `close_enough(x, x, n) = true` for all `x`, `n`

### 2. Symmetry
- `close(x, y, n) = close(y, x, n)`
- `close_enough(x, y, n) = close_enough(y, x, n)`

### 3. Implication (close → close_enough)
- `close(x, y, n) → close_enough(x, y, n)`

### 4. Monotonicity in tolerance
- If `close(x, y, n)` and `m ≥ n`, then `close(x, y, m)` (for non-zero x, y; the zero case uses `(n·ε)²` which is also monotone).
- Same for `close_enough`.

### 5. Exactness at zero tolerance
- `close(x, y, 0) ↔ x == y` (since tolerance = 0, relative test becomes `|x-y| ≤ 0`, and zero-case becomes `|x-y| < 0` which is false).
- Note: this relies on IEEE semantics. In Lean we'd model n=0 separately.

### 6. Non-transitivity
- `close` and `close_enough` are NOT transitive. This is a known property of floating-point closeness relations.

### 7. Consistency of overloads
- `close(x, y)` = `close(x, y, 42)`
- `close_enough(x, y)` = `close_enough(x, y, 42)`

## Edge Cases

| Case | `close` | `close_enough` | Notes |
|------|---------|----------------|-------|
| `x = y = 0` | `true` | `true` | Via `x == y` short-circuit |
| `x = 0, y = tiny` | `|y| < (n·ε)²` | `|y| < (n·ε)²` | Zero branch: tolerance squared |
| `x = y = +∞` | `true` | `true` | Via `x == y` |
| `x = +∞, y = -∞` | `false` | `false` | `x == y` is false, `|x-y| = ∞` |
| `x = +∞, y = large` | `false` | `false` | `|x-y| = ∞`, tolerance = `∞` but IEEE `∞ ≤ ∞` is true... implementation-dependent |
| `x = NaN` | `false` | `false` | `NaN == NaN` is false, all comparisons with NaN are false |
| `x = 1, y = 1 + ε` | Depends on n | Depends on n | For n ≥ 1: `close` is true |

## Examples

```
close(1.0, 1.0 + 1e-14, 42)  →  true   (diff ≈ 1e-14, tol ≈ 42·2.22e-16 ≈ 9.33e-15; close because 1e-14 ≤ 9.33e-15 is false... actually false for default n=42)
close(1.0, 1.0 + 1e-15, 42)  →  true   (diff = 1e-15 ≤ 9.33e-15 · 1.0)
close(0.0, 1e-30, 42)        →  true   (diff = 1e-30 < (42·ε)² ≈ 8.7e-29)
close(1e10, 1e10 + 1.0, 42)  →  false  (diff = 1, tol = 42·ε·1e10 ≈ 9.33e-5; 1 > 9.33e-5)
```

## Inferred Intent

The author's intent (following Knuth) is to provide a notion of "approximately equal"
that is *relative* — the tolerance scales with the magnitude of the operands. The
`close` variant (AND) is conservative: both operands must see the difference as small
relative to themselves. The `close_enough` variant (OR) is permissive: it suffices
that the difference is small relative to *either* operand.

The special zero-case uses tolerance² as an absolute threshold, which is very tiny
(≈ 8.7e-29 for n=42). This prevents `close(0, x)` from being trivially true for
any nonzero x.

## Open Questions

1. **NaN handling**: The functions do not explicitly handle NaN. The `x == y` check returns false for NaN, and all subsequent comparisons also return false. This means `close(NaN, NaN) = false`. Is this the intended behaviour? (Likely yes, as NaN ≠ NaN by IEEE convention.)

2. **Infinity edge case**: What should `close(+∞, +∞·(1-ε))` return? The `x == y` check handles `+∞ == +∞`, but close-but-not-equal infinities produce NaN in `|x-y|`.

3. **Zero tolerance squared motivation**: Why `tolerance²` and not just `tolerance` for the zero case? This makes the absolute threshold extremely tight (≈ 1e-29). Is this intentional or overly conservative?

## Specification for Lean Modelling

For Lean, we model `close` and `close_enough` over abstract reals (or rationals) with a
rational tolerance parameter `ε`. The IEEE-specific edge cases (NaN, infinity, ±0) are
documented as **not captured** by the Lean model. The core properties (reflexivity,
symmetry, close → close_enough, monotonicity in tolerance) are the primary verification
targets.
