/* TEST_OUTPUT:
---
fail_compilation/test20414.c(1): Error: `size_t` is not defined, perhaps `#include <stddef.h>` ?
fail_compilation/test20414.c(2): Error: `ptrdiff_t` is not defined, perhaps `#include <stddef.h>` ?
fail_compilation/test20414.c(3): Error: `NULL` is not defined, perhaps `#include <stddef.h>` is needed?
fail_compilation/test20414.c(5): Error: undefined identifier `fooo`, did you mean function `foo`?
---
*/

#line 1
size_t x;
ptrdiff_t pd;
void *p = NULL;
void foo(void);
void (*fp)(void) = &fooo;
