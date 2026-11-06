@"hi" @42 @int @null module user_defined_attributes;

// https://github.com/dlang/dmd/issues/23271
static assert(__traits(getAttributes, user_defined_attributes).length == 4);
static assert(__traits(getAttributes, user_defined_attributes)[0] == "hi");
static assert(__traits(getAttributes, user_defined_attributes)[1] == 42);

enum Test;

@true @null @byte int x;
@(int) int y;
@"test" @`test2` @30 @'a' @__LINE__ void f();

@Test void h();

static assert(   __traits(getAttributes, x)[0] == true);
static assert(   __traits(getAttributes, x)[1] == null);
static assert(is(__traits(getAttributes, x)[2] == byte));

static assert(is(__traits(getAttributes, y)[0] == int));

static assert(   __traits(getAttributes, f)[0] == "test");
static assert(   __traits(getAttributes, f)[1] == "test2");
static assert(   __traits(getAttributes, f)[2] == 30);
static assert(   __traits(getAttributes, f)[3] == 'a');
static assert(   __traits(getAttributes, f)[4] == 12);

static assert(is(__traits(getAttributes, h)[0] == enum));

version (D_SIMD)
{
    @__vector(int[4]) int vec;
}
