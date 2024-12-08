/* REQUIRED_ARGS: -preview=dip1000 -Ifail_compilation/imports
TEST_OUTPUT:
---
fail_compilation/issue21685_main.d(16): Error: constructor `issue21685.E.this` is not accessible from module `issue21685_main`
    new E;
    ^
fail_compilation/issue21685_main.d(23): Error: constructor `issue21685.E.this` is not accessible from module `issue21685_main`
        super();
             ^
---
*/
import issue21685;

void main()
{
    new E;
}

class F : E
{
    this()
    {
        super();
    }
}
