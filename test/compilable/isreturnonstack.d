
struct S { int[10] a; }
int test1() @system;
S test2() @system;

static assert(__traits(isReturnOnStack, test1) == false);
static assert(__traits(isReturnOnStack, test2) == true);

