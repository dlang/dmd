/*
TEST_OUTPUT:
---
fail_compilation/edition_complex.d(17): Error: undefined identifier `ifloat`
fail_compilation/edition_complex.d(18): Error: undefined identifier `cfloat`
fail_compilation/edition_complex.d(19): Error: undefined identifier `idouble`
fail_compilation/edition_complex.d(20): Error: undefined identifier `cdouble`
fail_compilation/edition_complex.d(21): Error: undefined identifier `ireal`
fail_compilation/edition_complex.d(22): Error: undefined identifier `creal`
---
 */
@__edition_latest_do_not_use
module edition_complex;

void main()
{
    ifloat fi;
    cfloat fc;
    idouble di;
    cdouble dc;
    ireal ri;
    creal rc;
}
