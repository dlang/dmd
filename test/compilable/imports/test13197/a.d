module imports.test13197.a;

import imports.test13197.y;   // import class C
import imports.test13197.y.z; // import class D : C

void g()
{
  C c;
  c.f(); // no problem, C is declared in the same package

  D d;
  d.f(); // error! D doesn't define f(), C does, and we have access to C as demonstrated above
}


