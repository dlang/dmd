/*
TEST_OUTPUT:
---
fail_compilation/fail3.d(33): Error: incompatible types for ((a) + (b)): both operands are of type 'vec2'
---
*/

// DMD 0.79 linux: Internal error: ../ztc/cgcod.c 1459

template vector(T)
{
    struct vec2
    {
        T x, y;
    }

    // not struct member
    vec2 opAdd(vec2 a, vec2 b)
    {
        vec2 r;
        r.x = a.x + b.x;
        r.y = a.y + b.y;
        return r;
    }
}

alias vector!(float).vec2 vec2f;

int main()
{
    vec2f a, b;
    b.x = 3;
    a = a + b;
    //printf("%f\n", a.x);
    return 0;
}
