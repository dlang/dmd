module imports.test3602a;

class Base
{
   void method(int x, int y)
   in
   {
       assert(x > 0);
       assert(y > 0);
   }
   body
   {
   }
}
