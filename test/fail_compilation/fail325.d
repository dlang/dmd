void fun(T=int)(int w, int z) {}

void main() {
    auto x = cast(void function(int, int))fun;
}

