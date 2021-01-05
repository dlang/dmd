/*
REQUIRED_ARGS: -preview=typefunctions
TEST_OUTPUT:
---
__emptyType
__emptyType
---
*/

alias type = __type__; 

// make sure the empty type cause the is expression to return false
static assert(!is(__emptyType));

/// test that the initial value of a type variable is the empty type
type tInitVar()
{
    type var;
    assert(!is(var));
    return var;
}

pragma(msg, tInitVar());

/// test that the initial value of a __type__.init is the empty type
type tInit()
{
    assert(!is(type.init));
    return type.init;
}

pragma(msg, tInit());

// assert that the type of a type is type
static assert(is(typeof(int) == type));
static assert(is(typeof(int) == typeof(char)));
// that goes for type as well, since the type type is a type itself
static assert(is(typeof(type) == type));
