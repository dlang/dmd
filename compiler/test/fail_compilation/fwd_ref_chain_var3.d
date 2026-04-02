/*
TEST_OUTPUT:
---
fail_compilation/fwd_ref_chain_var3.d(15): Error: circular reference to variable `fwd_ref_chain_var3.x`
fail_compilation/fwd_ref_chain_var3.d(15):        while resolving `fwd_ref_chain_var3.z`
fail_compilation/fwd_ref_chain_var3.d(14):        while resolving `fwd_ref_chain_var3.y`
fail_compilation/fwd_ref_chain_var3.d(13):        while resolving `fwd_ref_chain_var3.x`
---
*/
// https://github.com/dlang/dmd/pull/XXXX
// Test that 3-way circular variable type inference shows the full resolution chain.

auto x = y + 1;
auto y = z + 1;
auto z = x + 1;
