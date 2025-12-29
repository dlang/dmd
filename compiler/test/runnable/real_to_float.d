/* The test related to https://github.com/dlang/dmd/issues/22322
 * The issue title:
 * "converting real to float uses double rounding for 64-bit code
 * causing unexpected results"
 */
void main()
{
    version (X86_64)
    {
        real r = 0.5000000894069671353303618843710864894092082977294921875;
        float f = r;
        assert(f == 0x1.000002p-1);
    }
}
