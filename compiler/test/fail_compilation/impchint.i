/*
TEST_OUTPUT:
---
fail_compilation/impchint.i(33): Error: `bool` is not defined, perhaps `#include <stdbool.h>` ?
fail_compilation/impchint.i(33): Error: `true` is not defined, perhaps `#include <stdbool.h>` is needed?
fail_compilation/impchint.i(34): Error: `nullptr_t` is not defined, perhaps `#include <stddef.h>` ?
fail_compilation/impchint.i(35): Error: `int8_t` is not defined, perhaps `#include <stdint.h>` ?
fail_compilation/impchint.i(35): Error: `INT8_MAX` is not defined, perhaps `#include <stdint.h>` is needed?
fail_compilation/impchint.i(36): Error: `uint32_t` is not defined, perhaps `#include <stdint.h>` ?
fail_compilation/impchint.i(36): Error: `UINT32_MAX` is not defined, perhaps `#include <stdint.h>` is needed?
fail_compilation/impchint.i(37): Error: `wchar_t` is not defined, perhaps `#include <stddef.h>` ?
fail_compilation/impchint.i(37): Error: `WCHAR_MIN` is not defined, perhaps `#include <wchar.h>` is needed?
fail_compilation/impchint.i(38): Error: `FILE` is not defined, perhaps `#include <stdio.h>` is needed?
fail_compilation/impchint.i(38): Error: undefined identifier `f`
fail_compilation/impchint.i(39): Error: `fpos_t` is not defined, perhaps `#include <stdio.h>` ?
fail_compilation/impchint.i(39): Error: `EOF` is not defined, perhaps `#include <stdio.h>` is needed?
fail_compilation/impchint.i(40): Error: `EXIT_SUCCESS` is not defined, perhaps `#include <stdlib.h>` is needed?
fail_compilation/impchint.i(41): Error: `va_list` is not defined, perhaps `#include <stdarg.h>` ?
fail_compilation/impchint.i(43): Error: `exit` is not defined, perhaps `#include <stdlib.h>` is needed?
fail_compilation/impchint.i(44): Error: `getchar` is not defined, perhaps `#include <stdio.h>` is needed?
fail_compilation/impchint.i(45): Error: `offsetof` is not defined, perhaps `#include <stddef.h>` is needed?
fail_compilation/impchint.i(46): Error: `strcat` is not defined, perhaps `#include <string.h>` is needed?
fail_compilation/impchint.i(48): Error: `false` is not defined, perhaps `#include <stdbool.h>` is needed?
---
*/





int test(void)
{
    bool a = true;
    nullptr_t b;
    int8_t c = INT8_MAX;
    uint32_t d = UINT32_MAX;
    wchar_t e = WCHAR_MIN;
    FILE *f = NULL;
    fpos_t g = EOF;
    int h = EXIT_SUCCESS;
    va_list i;

    exit();
    getchar();
    offsetof();
    strcat();

    return false;
}
