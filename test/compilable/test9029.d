/* TEST_OUTPUT:
---
---
*/
enum NameOf(alias S) = S.stringof;

static assert(NameOf!int == "int");

enum BothMatch(alias S) = "alias";
enum BothMatch(T) = "type";

void foo9029() { }

struct Struct { }

static assert(BothMatch!int == "type");
static assert(BothMatch!(void function()) == "type");
static assert(BothMatch!BothMatch == "alias");
static assert(BothMatch!Struct == "type");
static assert(BothMatch!foo9029 == "alias");
static assert(BothMatch!5 == "alias");
