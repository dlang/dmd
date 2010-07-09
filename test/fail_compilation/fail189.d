void bar ()
{
        foo (); // should fail
}

version(none):
void foo () {}

