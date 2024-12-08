// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -wi -o-

/+
TEST_OUTPUT:
---
compilable/ddoc4899.d(21): Warning: Ddoc: Stray '('. This may cause incorrect Ddoc output. Use $(LPAREN) instead for unpaired left parentheses.
/** ( */ int a;
             ^
compilable/ddoc4899.d(22): Warning: Ddoc: Stray ')'. This may cause incorrect Ddoc output. Use $(RPAREN) instead for unpaired right parentheses.
/** ) */ int b;
             ^
---
+/

//       (See accompanying file LICENSE_1_0.txt or copy at
//        foo:)

module d;

/** ( */ int a;
/** ) */ int b;

void main()
{
}
