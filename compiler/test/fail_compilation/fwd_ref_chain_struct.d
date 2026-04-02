/*
TEST_OUTPUT:
---
fail_compilation/fwd_ref_chain_struct.d(13): Error: struct `fwd_ref_chain_struct.A` no size because of forward reference
fail_compilation/fwd_ref_chain_struct.d(13):        while resolving `fwd_ref_chain_struct.A`
fail_compilation/fwd_ref_chain_struct.d(13):        while resolving `fwd_ref_chain_struct.B`
---
*/
// https://github.com/dlang/dmd/pull/XXXX
// Test that circular struct size dependency shows the resolution chain.

struct A { B b; }
struct B { A a; }
