// PERMUTE_ARGS:
// REQUIRED_ARGS: -o- -X -Xftest_results/compilable/json.out
// POST_SCRIPT: compilable/extra-files/json-postscript.sh

struct X;

enum Y;

// 3404
alias int myInt;
myInt x;

// 3466
struct Foo3466(T) { T t; }
class  Bar3466(T) { T t; }

// 4178

struct  Bar4178 {
  this(int i)  { }
  this(this) { }
  ~this() { }
}


