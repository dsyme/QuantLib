# Matrix — Informal Specification

🔬 *Lean Squad — automated formal verification.*

## Purpose

The `Matrix` class (`ql/math/matrix.hpp`, `ql/math/matrix.cpp`) implements a dense 2D matrix of `Real` (double) values for use in linear algebra within QuantLib. It provides element-wise arithmetic, matrix multiplication, transpose, outer product, inverse (via LU decomposition), and determinant computation.

## Scope for Formal Verification

We focus on the **algebraic properties** of matrix operations over a rational (`ℚ`) model, abstracting away floating-point rounding. The key benefit is that the algebraic laws (associativity, distributivity, transpose involution, etc.) are simple to state yet constrain a complex ~755-line C++ implementation.

## Data Representation

- A matrix is a 2D array of `Real` values with dimensions `rows × columns`.
- Storage is row-major: element `(i, j)` is at index `i * columns + j`.
- An empty matrix has `rows = 0` or `columns = 0`.

## Preconditions

### Arithmetic (element-wise)
- **Addition/Subtraction** (`+`, `-`, `+=`, `-=`): both operands must have the same dimensions.
- **Scalar multiply/divide** (`*`, `/`, `*=`, `/=`): scalar divisor must be non-zero (for `/`).

### Matrix multiplication
- `A * B` requires `A.columns() == B.rows()`. Result has dimensions `A.rows() × B.columns()`.
- `v * M` (row-vector × matrix): `v.size() == M.rows()`. Result has size `M.columns()`.
- `M * v` (matrix × column-vector): `v.size() == M.columns()`. Result has size `M.rows()`.

### Transpose
- No precondition. Result has dimensions `columns × rows`.

### Inverse / Determinant
- Matrix must be square (`rows == columns`).
- For `inverse`: matrix must be non-singular.

## Postconditions & Key Properties

### Algebraic Laws (element-wise operations)

1. **Addition commutativity**: `A + B = B + A`
2. **Addition associativity**: `(A + B) + C = A + (B + C)`
3. **Additive identity**: `A + 0 = A` (zero matrix of same dimensions)
4. **Additive inverse**: `A + (-A) = 0`
5. **Scalar multiplication distributes over addition**: `c * (A + B) = c*A + c*B`
6. **Scalar multiplication associativity**: `a * (b * M) = (a * b) * M`
7. **Scalar multiplicative identity**: `1 * M = M`

### Transpose Properties

8. **Involution**: `transpose(transpose(A)) = A`
9. **Distributes over addition**: `transpose(A + B) = transpose(A) + transpose(B)`
10. **Transpose of scalar multiply**: `transpose(c * A) = c * transpose(A)`
11. **Transpose dimension**: `transpose(A).rows() = A.columns()` and `transpose(A).columns() = A.rows()`

### Matrix Multiplication Properties

12. **Associativity**: `(A * B) * C = A * (B * C)` (when dimensions match)
13. **Left-distributivity**: `A * (B + C) = A*B + A*C`
14. **Right-distributivity**: `(A + B) * C = A*C + B*C`
15. **Scalar compatibility**: `c * (A * B) = (c * A) * B`
16. **Transpose reverses product**: `transpose(A * B) = transpose(B) * transpose(A)`

### Diagonal

17. `diagonal(A).size() = min(A.rows(), A.columns())`
18. `diagonal(A)[i] = A(i, i)` for all valid `i`

### Outer Product

19. `outerProduct(v1, v2).rows() = v1.size()`
20. `outerProduct(v1, v2).columns() = v2.size()`
21. `outerProduct(v1, v2)(i, j) = v1[i] * v2[j]`

### Inverse (square, non-singular)

22. `A * inverse(A) = I` (identity matrix)
23. `inverse(A) * A = I`

### Determinant (square)

24. `determinant(I) = 1`
25. `determinant(A * B) = determinant(A) * determinant(B)` (for same-size square matrices)

## Edge Cases

- **Empty matrix**: `rows=0` or `columns=0`. `empty()` returns `true`. Arithmetic on empty matrices of matching dimensions should produce empty matrices.
- **1×1 matrix**: behaves as a scalar wrapper.
- **Non-square matrices**: inverse and determinant are undefined (precondition violation).

## Inferred Intent

The Matrix class is designed as a mathematical abstraction obeying standard linear algebra axioms. The move-optimization overloads (`Matrix&&`) are performance optimizations that must preserve the same algebraic semantics as the const-reference overloads.

## Open Questions

1. The initializer_list constructor only checks row-length consistency when `QL_EXTRA_SAFETY_CHECKS` is defined — should this always be checked?
2. Division by zero in `operator/=` is not guarded — is this intentional (relying on IEEE infinity)?

## FV Priority & Approach

**Spec-to-implementation complexity ratio: High.** The algebraic laws are a handful of clean, textbook identities, yet the implementation spans 755 lines of C++ with multiple move-optimized overloads, raw pointer arithmetic, and row-major storage. A concise Lean spec constraining these operations is much simpler than the code it verifies.

**Approach**: Model matrices as `List (List ℚ)` or Mathlib's `Matrix` type. State the algebraic laws as theorems. Proofs should largely follow from Mathlib's existing `Matrix` algebra lemmas. Focus on the properties that are most likely to catch indexing bugs: transpose involution, multiplication associativity, outer product definition.
