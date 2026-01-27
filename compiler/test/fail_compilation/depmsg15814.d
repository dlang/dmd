// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/depmsg15814.d(10): Deprecation: function `depmsg15814.get15814` is deprecated - bug15814
fail_compilation/depmsg15814.d(9):        `get15814` is declared here
---
*/
deprecated("bug15814") int get15814() { return 0; }
enum val15814 = get15814();
