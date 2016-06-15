/* REQUIRED_ARGS: -w
 * TEST_OUTPUT:
---
fail_compilation/test16176.d(12): Warning: statement is not reachable
---
*/
// https://issues.dlang.org/show_bug.cgi?id=16176

  void main () {
    char ch = '!';
    switch (ch) {
      ch = 'a';
      case '!': break;
      default:
    }
  }


