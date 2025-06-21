/* TEST_OUTPUT:
---
fail_compilation/ice21256.d(8): Error: empty hex string
---
*/
void main ()
{
   cast (ubyte []) [x""];
}

