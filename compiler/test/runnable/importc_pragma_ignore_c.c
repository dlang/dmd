// EXTRA_SOURCES: imports/importc_pragma_ignore.d

// For `size_t`.
#include <stddef.h>

__import importc_pragma_ignore;

// A trailing comma is allowed for the identifiers.
#pragma importc_ignore(+function_decl : foo, memset,)

// The ignoring of `foo` and `memset` is still in effect after this.
#pragma importc_ignore(+function_decl +function_def : bar)

// This compiler should ignore this function declaration, and so the linker
// shouldn't complain about `foo` being undefined when it's called in `useFoo`,
// as the definition of `foo` from `importc_pragma_ignore` should be used.
int foo(void);

int useFoo()
{
    return foo();
}

typedef struct HasFoo
{
    int foo;
}
Foo;

void *memset(void *);
#pragma importc_ignore(-function_decl : memset)
// The previous declaration of `memset` was ignored, so this redefinition
// with a different type should succeed.
void *memset(void *, int, size_t);

int bar(int x)
{
	return 0;
}

int main(void)
{
    __check(useFoo() == 1);

    // The ignoring shouldn't interfere with non-functions.
    HasFoo hasFoo = {.foo = 7};
    ++hasFoo.foo;
    __check(hasFoo.foo == 8);

    __check(bar(2) == 4);

    unsigned char value = 0;
    memset(&value, 111, 1);
    __check(value == 111);

    return 0;
}
