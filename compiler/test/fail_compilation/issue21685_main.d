/* REQUIRED_ARGS: -preview=dip1000 -Ifail_compilation/imports
TEST_OUTPUT:
---
fail_compilation/issue21685_main.d(12): Error: class `issue21685.E` constructor `this` is not accessible
fail_compilation/issue21685_main.d(19): Error: class `issue21685.E` constructor `this` is not accessible
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
