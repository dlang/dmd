/* TEST_OUTPUT:
---
fail_compilation/fail21347.d(19): Error: expression expected, not `;`
fail_compilation/fail21347.d(20): Error: found `}` when expecting `,`
fail_compilation/fail21347.d(19): Error: found `End of File` when expecting `]`
fail_compilation/fail21347.d(19): Error: found `End of File` when expecting `)`
fail_compilation/fail21347.d(21): Error: found `End of File` when expecting `;` following expression
fail_compilation/fail21347.d(19):        expression: `[(__error)]`
fail_compilation/fail21347.d(21): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/fail21347.d(18):        unmatched `{`
---
*/

// https://github.com/dlang/dmd/issues/21347
// diagnostic: Parser never stops looking for ',' on array literal syntax error

void test21347()
{
    ([;
}
