TypeInfo names for aggregates are fully qualified and hence unique now

Previously, template arguments weren't fully qualified; they now are,
implying longer names in that case.

`TypeInfo_Struct` instances now store the (potentially significantly shorter)
mangled name only and demangle it lazily on the first `name` or `toString()`
call (with a per-thread cache). So if you only need a unique string per
struct TypeInfo, prefer `mangledName` over computed `name` (non-`@nogc` and
non-`pure`).

**Related breaking change**: `TypeInfo.toString()` isn't `pure` anymore to
account for the `TypeInfo_Struct` demangled name cache.
`TypeInfo_Class.toString()` and others are still `pure`.
