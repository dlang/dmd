/*
TEST_OUTPUT:
---
fail_compilation/fwd_ref_chain_var.d(13): Error: circular reference to variable `fwd_ref_chain_var.x`
fail_compilation/fwd_ref_chain_var.d(13):        while resolving `fwd_ref_chain_var.y`
fail_compilation/fwd_ref_chain_var.d(12):        while resolving `fwd_ref_chain_var.x`
---
*/
// https://github.com/dlang/dmd/pull/XXXX
// Test that circular variable type inference shows the resolution chain.

auto x = y + 1;
auto y = x + 1;
