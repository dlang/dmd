
enum x = 10;
enum Thing { A, B }
enum IsThing(T) = is(T == enum) || (__traits(getLinkage, T) == "C++");
enum Is = IsThing!Thing;

static assert(Is);

enum Another(T) = is(T == int) && (__traits(getLinkage, T) == "C++");

static assert(!Another!Thing);
