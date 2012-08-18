// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 5

/**

  Test module

*/
module test;

/// class to test DDOC on members
class TestMembers(TemplateArg)
{
  public:
    /**

       a static method 

       Params: idx = index
   
    */
    static void PublicStaticMethod(int  idx)
    {
    }
}

void main()
{
}

