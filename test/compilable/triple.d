/* The following arguments to the autotester do not work because it is
 * determined to add -fPICx, even though the documentation says xERMUTE_ARGSx
 * with no arguments will prevent it.
 */
/* EQUIRED_ARGSx -m64 -target=x64-windows-msvc -mscrtlib=whatever.lib
 * ERMUTE_ARGSx
 */

int func(int x)
{
    return x + 1;
}
