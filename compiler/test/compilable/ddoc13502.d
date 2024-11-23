// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -wi -o-
/*
TEST_OUTPUT:
---
compilable/ddoc13502.d(22): Warning: Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.
enum isSomeString(T) = true;
     ^
compilable/ddoc13502.d(25): Warning: Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.
enum bool isArray(T) = true;
          ^
compilable/ddoc13502.d(29): Warning: Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.
extern(C) alias int T1;
          ^
compilable/ddoc13502.d(32): Warning: Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.
extern(C) alias T2 = int;
          ^
---
*/

/// (
enum isSomeString(T) = true;

/// (
enum bool isArray(T) = true;


/// (
extern(C) alias int T1;

/// (
extern(C) alias T2 = int;
