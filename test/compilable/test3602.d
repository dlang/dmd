// EXTRA_SOURCES: imports/test3602a.d
// https://issues.dlang.org/show_bug.cgi?id=5230

import imports.test3602a;

class Derived : Base
{
   override void method(int x, int y)
   in
   {
       assert(x > 0);
       assert(y > 0);
   }
   body
   {
   }
}
