module imports.speculative_emission;

int f() { int[int] aa; return 1; }
enum x = f();
int g()() { int[long] aa; return 1; }
enum y = g();

enum fp = () => 3;
alias F = () => 4;
