// REQUIRED_ARGS: -verrors=simple -D -Dd${RESULTS_DIR}/compilable -o- -w -c
/* TEST_OUTPUT:
---
compilable/ddoc18083.d(12): Warning: Ddoc: function declaration has no parameter 'this'
compilable/ddoc18083.d(12): Warning: Ddoc: parameter count mismatch, expected 0, got 1
---
*/
/**
Params:
  this = non-existent parameter
*/
int foo()
{
    return 1;
}
