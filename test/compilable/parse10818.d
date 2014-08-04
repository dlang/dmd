// PERMUTE_ARGS:

enum E1(T) { a, b }
static assert(E1!int.a == 0);
static assert(E1!int.b == 1);

enum E2(T) if (true) { a, b }
static assert(E2!int.a == 0);
static assert(E2!int.b == 1);

enum E3(T) : T { a, b }
static assert(E3!int.a == 0);
static assert(E3!int.b == 1);
static assert(E3!double.a == 0.0);
static assert(E3!double.b == 1.0);

enum E4(T) if (true) : T { a, b }
static assert(E4!int.a == 0);
static assert(E4!int.b == 1);
static assert(E4!double.a == 0.0);
static assert(E4!double.b == 1.0);

enum E5(T) : T if (true) { a, b }
static assert(E5!int.a == 0);
static assert(E5!int.b == 1);
static assert(E5!double.a == 0.0);
static assert(E5!double.b == 1.0);
