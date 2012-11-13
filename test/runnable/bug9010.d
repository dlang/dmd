// PERMUTE_ARGS: 
// POST_SCRIPT: runnable/extra-files/bug9010-postscript.sh 
// REQUIRED_ARGS: -cov 
 
struct A
{
    bool opEquals(A o) const
    {
        return false;
    }
    
}

extern(C) void dmd_coverDestPath(string pathname); 

void main()
{
    dmd_coverDestPath("test_results/runnable"); 

    auto a = A();
    auto b = A();
    assert(a != b);
}
