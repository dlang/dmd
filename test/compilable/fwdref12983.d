// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

alias I = int;
class B(T) { alias MyC = C!string; }

class C(T) : B!float
{
    void m() { f(0); }
}

alias MyB = B!float;

void f();
void f(I);
