import core.stdc.stdio;

T f(T)(T x) { return x-1; }

int main(string[] args) {
    int x = f(1);
    printf("%d\n", x);
    return x;
}
