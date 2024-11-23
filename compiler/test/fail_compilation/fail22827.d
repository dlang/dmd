// https://issues.dlang.org/show_bug.cgi?id=22827
/* TEST_OUTPUT:
---
fail_compilation/fail22827.d(12): Error: `cent` and `ucent` types are obsolete, use `core.int128.Cent` instead
cent i22827;
     ^
fail_compilation/fail22827.d(13): Error: `cent` and `ucent` types are obsolete, use `core.int128.Cent` instead
ucent j22827;
      ^
---
*/
cent i22827;
ucent j22827;
