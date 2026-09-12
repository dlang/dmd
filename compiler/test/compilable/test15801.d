enum foo(alias sym) = 3;

string str;

static assert(foo!str == 3);

enum bar(int n) = 2;
enum bar(alias sym) = 3;

static assert(bar!str == 3);
