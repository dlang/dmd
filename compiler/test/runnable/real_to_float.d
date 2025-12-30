/* The test related to https://github.com/dlang/dmd/issues/22322
 * The issue title:
 * "converting real to float uses double rounding for 64-bit code
 * causing unexpected results"
 */
void main()
{
    static if (real.sizeof > 8)
    {
        real r = 0.5000000894069671353303618843710864894092082977294921875;
        assert(r == 0x1.000002fffffffcp-1);
        float d = r;
        assert(d == 0x1.000003p-1);
        float f = r;
        assert(f == 0x1.000002p-1);
    }
}
