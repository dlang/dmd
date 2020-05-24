module imports.a8392;

import ice8392;

class B
{
    this(B) @system;
}

void foob(A a, B b)
{
    a.fooa!((arg){
            return new B(b);
    });
}
