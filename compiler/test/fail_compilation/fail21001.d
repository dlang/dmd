/*
TEST_OUTPUT:
---
fail_compilation/fail21001.d(14): Error: undefined identifier `Alias`
void main() { Alias var; }
                    ^
---
*/

module fail21001;

import imports.fail21001b;

void main() { Alias var; }
