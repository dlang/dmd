/*
TEST_OUTPUT:
---
fail_compilation/ice11857.d(10): Error: cannot have const out parameter of type const(int)
---
*/


void t11857(T)(T) { }
void t11857(T)(out T) if(false) { }


void main()
{
    const int n = 1;
    t11857(n); // causes ICE
}


