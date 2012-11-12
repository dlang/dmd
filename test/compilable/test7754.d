// REQUIRED_ARGS: -H -Hdtest_results/compilable
// POST_SCRIPT: compilable/extra-files/test7754-postscript.sh
// PERMUTE_ARGS: -d -di

struct Foo(T)
{
   shared static this()
   {
   }

   static this()
   {
   }
}
