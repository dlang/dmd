typedef struct _SCOPE_TABLE_AMD64 {
    struct { int x; } ScopeRecord[1];
} _SCOPE_TABLE_AMD64;

typedef struct _SCOPE_TABLE_UNION {
    union { int a; float b; } U[2];
    struct { int y; } Nested[2][3];
} _SCOPE_TABLE_UNION;
