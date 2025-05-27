/*
RUN_OUTPUT:
---
a
b
---
*/
enum SomethingSuperBig {A, B, C}

void main()
{
    SomethingSuperBig something = _.A;

    if (something == _.B)
    {
        printf("b\n");
    }
    else if (something == _.A)
    {
        printf("a\n");
    }

    something = _.B;

    switch (something)
    {
        case _.A: printf("a\n"); break;
        case _.B: printf("b\n"); break;
        default: break;
    }
}

// utility
extern(C) int printf(scope const char* format, scope const ...);

struct Symbol(string name) {
    T opImplicitCast(T)() {
        return __traits(getMember, T, name);
    }

    bool opEquals(T)(T t) const {
        return t == __traits(getMember, T, name);
    }
}

struct _ {
    static ref enum opDispatch(string name) = Symbol!name.init;
}

