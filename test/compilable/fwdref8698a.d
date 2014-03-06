// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

interface IRoot {}

interface IClass : IRoot { }

struct Struct { }

class Class : IClass { alias Struct Value; }

void test(Class.Value) { }

//interface IRoot {}
