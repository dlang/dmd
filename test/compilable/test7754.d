// PERMUTE_ARGS:
// REQUIRED_ARGS: -H -Hdtest_results/compilable
// POST_SCRIPT: compilable/extra-files/test7754-postscript.sh
// REQUIRED_ARGS: -d

struct Foo(T)
{
   shared static this()
   {
   }

   static this()
   {
   }
}
