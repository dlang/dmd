// https://github.com/dlang/dmd/issues/19569
// https://github.com/dlang/dmd/issues/23367
//
// Test that casting a short string to a large static array uses sparse
// representation instead of eagerly allocating O(N) memory.
//
// Without the fix, `cast(char[N]) "ab"` would allocate ~N bytes of
// zero-filled storage in the front-end, potentially consuming GBs of
// memory and blowing up the compiler for large N.
//
// With the fix, the StringExp retains its original small backing buffer
// and records a basis fill value; the full buffer is only materialized
// on demand (e.g. codegen or writeTo).

// -----------------------------------------------------------
// 1. Large char array — would allocate ~100 MB without fix
// -----------------------------------------------------------
static assert((cast(char[100_000_000]) "ab")[0] == 'a');
static assert((cast(char[100_000_000]) "ab")[1] == 'b');
static assert((cast(char[100_000_000]) "ab")[2] == 0);
static assert((cast(char[100_000_000]) "ab")[99_999_999] == 0);

// -----------------------------------------------------------
// 2. Large wchar array — would allocate ~200 MB without fix
// -----------------------------------------------------------
static assert((cast(wchar[50_000_000]) "xy"w)[0] == 'x');
static assert((cast(wchar[50_000_000]) "xy"w)[1] == 'y');
static assert((cast(wchar[50_000_000]) "xy"w)[2] == 0);
static assert((cast(wchar[50_000_000]) "xy"w)[49_999_999] == 0);

// -----------------------------------------------------------
// 3. Large dchar array — would allocate ~400 MB without fix
// -----------------------------------------------------------
static assert((cast(dchar[25_000_000]) "mn"d)[0] == 'm');
static assert((cast(dchar[25_000_000]) "mn"d)[1] == 'n');
static assert((cast(dchar[25_000_000]) "mn"d)[2] == 0);
static assert((cast(dchar[25_000_000]) "mn"d)[24_999_999] == 0);

// -----------------------------------------------------------
// 4. CTFE: sparse string through enum / static assert
// -----------------------------------------------------------
enum e = cast(char[50_000_000]) "CTFE";
static assert(e[0] == 'C');
static assert(e[1] == 'T');
static assert(e[2] == 'F');
static assert(e[3] == 'E');
static assert(e[4] == 0);
static assert(e[49_999_999] == 0);

// -----------------------------------------------------------
// 5. Non-sparse path still works (smaller than source)
// -----------------------------------------------------------
enum t = cast(char[3]) "hello";
static assert(t[0] == 'h');
static assert(t[1] == 'e');
static assert(t[2] == 'l');

// -----------------------------------------------------------
// 6. Same-size cast still works
// -----------------------------------------------------------
enum s = cast(char[5]) "hello";
static assert(s[0] == 'h');
static assert(s[4] == 'o');

// -----------------------------------------------------------
// 7. copyLiteralArrayExpand: sparse array concat with basis
//    Without the fix, concatenating two large sparse arrays
//    would create N independent copies of the basis element.
// -----------------------------------------------------------
static int testCatSparse()
{
    int[5000] a = 1;
    int[5000] b = 2;
    auto c = a ~ b;
    return c[0] + c[2500] + c[4999] + c[5000] + c[7500] + c[9999];
}
static assert(testCatSparse() == 1 + 1 + 1 + 2 + 2 + 2);

// -----------------------------------------------------------
// 8. Repeated concat of sparse arrays (tests copyLiteral)
// -----------------------------------------------------------
static int testRepeatedConcat()
{
    int[1000] a = 7;
    auto b = a ~ a ~ a;
    return b[0] + b[999] + b[1000] + b[2999];
}
static assert(testRepeatedConcat() == 7 + 7 + 7 + 7);

// -----------------------------------------------------------
// 9. Truncation path (dim2 < se.len in dcast.d)
// -----------------------------------------------------------
enum tr = cast(char[2]) "hello";
static assert(tr[0] == 'h');
static assert(tr[1] == 'e');

// -----------------------------------------------------------
// 10. Multiple large casts (tests that copies preserve sparse encoding)
// -----------------------------------------------------------
static assert((cast(char[50_000_000]) "A")[0] == 'A');
static assert((cast(char[50_000_000]) "A")[49_999_999] == 0);
static assert((cast(char[50_000_000]) "B")[0] == 'B');
static assert((cast(char[50_000_000]) "B")[49_999_999] == 0);

// -----------------------------------------------------------
// 11. Sparse extending a longer source that itself was extended.
//     This exercised the bug where e.copy() carried stale
//     hasBasis/dataLen from a previously-sparse source string.
// -----------------------------------------------------------
static assert((cast(char[200]) "abcde")[4] == 'e');
static assert((cast(char[200]) "abcde")[5] == 0);
static assert((cast(char[200]) "abcde")[199] == 0);
static assert((cast(char[500]) "abcde")[4] == 'e');
static assert((cast(char[500]) "abcde")[5] == 0);
static assert((cast(char[500]) "abcde")[499] == 0);
