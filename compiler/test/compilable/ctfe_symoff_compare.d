// Comparing structs that hold the address of a global, at compile time

__gshared int g;
__gshared int[4] arr;

struct P { size_t n; int* p; }
struct Q { size_t n; const(void)* p; }

static assert(P(1, &g) == P(1, &g));
static assert(P(1, &g) != P(1, &arr[1]));
static assert(P(1, &arr[1]) == P(1, &arr[1]));
static assert(P(1, &arr[1]) != P(1, &arr[2]));
static assert(P(1, &g) is P(1, &g));

enum q = Q(1, &g);
static assert(q == q);
static assert(q is q);

enum bool ctfe = () {
    P a = P(1, &g), b = P(1, &g), c = P(1, &arr[0]);
    return a == b && a is b && a != c && [a] == [b];
}();
static assert(ctfe);
