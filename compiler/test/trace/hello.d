import std.stdio;

T f(T)(T x) { return x-1; }

int main(string[] args) {
    int x = f(1);
    writeln(x);
    return x;
}
