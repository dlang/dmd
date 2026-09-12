## 1. Theoretical Foundations & Literature Lineage

* **Type Theory & Category Theory**: A sum type $A + B$ represents a coproduct (disjoint union). The introduction rules are injections ($\text{inl} : A \to A+B$, $\text{inr} : B \to A+B$), and the elimination rule is case analysis (pattern matching).
* **Hope (Burstall, MacQueen, Sannella, 1980)**: Introduced algebraic data types (ADTs) paired with explicit pattern-matching syntax for function clauses.
* **ML & Haskell (Milner et al., 1980s; Hudak et al., 1990)**: Formalized nominal ADTs using Hindley-Milner type inference, making variants top-level primitives identified by unique type constructors.

---

## 2. Structural vs. Nominal Typing & Reserved Keywords (`__sumtype`)

### Keyword Hygiene (`__sumtype`)

To prevent breaking existing code bases (specifically Phobos's `std.sumtype` library module and user symbols named `sumtype`), the feature uses the implementation-reserved keyword **`__sumtype`**.

* **Type Declaration Syntax**:
```d
alias S = __sumtype(int | bool);
// or
__sumtype S = int | bool;

```



### Structural vs. Nominal Semantics

* **Algebraic Properties**: Structural set-theoretic unions (`int | bool`) exhibit **commutativity** ($A \vert{} B \equiv B \vert{} A$), **associativity** ($(A \vert{} B) \vert{} C \equiv A \vert{} (B \vert{} C)$), and **idempotency** ($A \vert{} A \equiv A$).
* **The Duplicate Labeling Rule**: Because set theory collapses $A \cup A \equiv A$, a purely type-based structural union `__sumtype(int | int)` is inherently ambiguous during pattern matching.
* *Constraint*: Unlabeled duplicate payload types in structural syntax are prohibited at compile time. If identical payload types are required, explicit field labels or nominal constructor syntax must be used.



---

## 3. Compilation & Decision Tree Synthesis

Translating nested patterns into efficient machine code (minimizing memory lookups and branch mispredictions) relies on well-established algorithms:

* **Augustsson (1985)** & **Wadler (1987)**: Established matrix-based pattern compilation. Patterns are organized in a 2D grid (row-by-row cases, column-by-column constructor tests) and compiled into deterministic decision trees.
* **Luc Maranget (2007)** (*Compiling Pattern Matching to Good Decision Trees*, INRIA): The standard modern reference (OCaml, Rust, Swift). Maranget's matrix algorithm provides heuristics for minimal-depth decision trees and guarantees two critical static diagnostics:
* **Exhaustiveness Checking**: Verifies that match arms cover $100\%$ of the sum type's state space.
* **Redundancy Checking**: Detects unreachable/dead code branches subsumed by earlier patterns.



---

## 4. Systems Programming Pragmatics & Memory Layout

Implementing sum types in an unmanaged systems language like D introduces low-level layout and safety constraints:

### Niche Optimization / Discriminant Elision (Rust RFC 1238, Swift ABI)

The compiler reuses invalid bit patterns ("niches") in payload types rather than allocating separate discriminator bytes whenever possible:

* **Null Pointer Optimization (NPO)**: For non-nullable class references, pointers, or `scope` references, `0x0` represents the empty/`None` variant, ensuring `sizeof(__sumtype(T* | None)) == sizeof(T*)`.
* **Range Niches**: Booleans (bits $2$–$255$ are unused), bounded enums, and aligned pointers (lower alignment bits are zero) store tag states at zero extra memory cost.

### Destruction & Exception Invariants

* **RAII**: Re-tagging a sum type instance from Variant A to Variant B requires running the destructor (`~this()`) of Variant A before initializing Variant B over the same memory location.
* **Exception Safety**: Move-assignments during re-tagging must be exception-safe or disallow throwing constructors, preventing the memory corruption of an invalid intermediate tag state (avoiding C++'s `valueless_by_exception` pitfall).

---

## 5. D-Specific Design Invariants

Integrating `__sumtype` directly into D requires four core design rules:

### A. Expression-Based & Chainable Matching

Match constructs are **expressions** rather than statements, returning a unified result type:

1. **Concrete Unification**: If all match arms evaluate to type $T$, the match expression evaluates to $T$.
2. **SumType Synthesis (Chaining)**: If arms evaluate to distinct types $T_1, T_2, \dots, T_n$, the result synthesizes a new `__sumtype`:

$$\text{ResultType} = \text{\_\_sumtype}(T_1 \mid T_2 \mid \dots \mid T_n)$$



This enables fluent method chaining without intermediate temporary variables:
```d
auto res = val
    .match!(
        case int i    => i * 2.0,      // returns double
        case string s => None()        // returns None
    ) // Evaluates to __sumtype(double | None)
    .match!(
        case double d => format("%f", d),
        case None     => "empty"
    ); // Evaluates to string

```



### B. Degenerate 1-Element Sum Types as Type Aliases

A single-element sum type contains zero runtime choices:


$$\text{\_\_sumtype}(T) \equiv T$$

```d
alias Degenerate = __sumtype(int); // Lowers directly to: alias Degenerate = int;

```

* **Impact**: Zero tag overhead, identical memory/ABI calling conventions to $T$, and matching degenerates to an immediate compile-time evaluation.

### C. Strict Value Semantics (No `ref` Access)

Pattern match bindings **strictly copy or move values out** of the sum type. Borrowing mutable references (`ref`) to internal fields is forbidden:

* **Safety Benefit**: Reassigning or re-tagging a sum type instance while reading a payload cannot cause memory corruption or invalid type reinterpretation.
* **Compiler Simplification**: Eliminates the need for complex lifetime tracking (DIP 1000) to lock the outer sum type during field borrowing.

### D. Absence & D's `.init` Guarantee

* **Representing `None**`: Represented as a zero-sized unit variant (e.g., `None` or `void`).
* **Static Initialization**: To satisfy D's requirement that every type has a predictable, compile-time static `.init` state, `__sumtype` defaults its `.init` to the `.init` of its first listed variant. Listing `None` first ensures uninitialized variables default safely to the "empty" state.

---

### Core Feature Matrix

| Feature | Specification | Rationale / Impact |
| --- | --- | --- |
| **Identifier** | `__sumtype` | Prevents breaking `std.sumtype` and existing codebase symbols. |
| **Matching Mode** | Expression-based (Chainable) | Unifies return types or synthesizes `__sumtype(T1 | T2)` results. |
| **1-Element Union** | `__sumtype(T)` $\to$ `alias ... = T;` | Eliminates tag overhead; matches payload ABI exactly. |
| **Reference Semantics** | **Value-Only** (No `ref`) | Guarantees safety during re-tagging without complex lifetime checks. |
| **Absence Representation** | `None` / Unit Variant | Provides a safe default `.init` value when positioned first. |

---
