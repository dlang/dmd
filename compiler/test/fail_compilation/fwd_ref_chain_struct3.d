/*
TEST_OUTPUT:
---
fail_compilation/fwd_ref_chain_struct3.d(15): Error: struct `fwd_ref_chain_struct3.A` no size because of forward reference
fail_compilation/fwd_ref_chain_struct3.d(15):        while resolving `fwd_ref_chain_struct3.A`
fail_compilation/fwd_ref_chain_struct3.d(15):        while resolving `fwd_ref_chain_struct3.C`
fail_compilation/fwd_ref_chain_struct3.d(14):        while resolving `fwd_ref_chain_struct3.B`
---
*/
// https://github.com/dlang/dmd/pull/XXXX
// Test that 3-way circular struct size dependency shows the full resolution chain.

struct A { B b; }
struct B { C c; }
struct C { A a; }
