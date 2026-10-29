/* REQUIRED_ARGS: -inline -Icompilable/extra-files
   EXTRA_SOURCES: extra-files/c6815.d
   TEST_OUTPUT:
---
good
---
 */

void b()
{
    import e6815 : e, e2;
    e("");
    e2("");
}
