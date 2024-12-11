/*
TEST_OUTPUT:
---
fail_compilation/ufcs.d(46): Error: no property `regularF` for `s` of type `S`
    s.regularF();
              ^
fail_compilation/ufcs.d(46):        the following error occured while looking for a UFCS match
fail_compilation/ufcs.d(46): Error: function `regularF` is not callable using argument types `(S)`
    s.regularF();
              ^
fail_compilation/ufcs.d(46):        expected 0 argument(s), not 1
fail_compilation/ufcs.d(51):        `ufcs.regularF()` declared here
void regularF();
     ^
fail_compilation/ufcs.d(47): Error: no property `templateF` for `s` of type `S`
    s.templateF();
               ^
fail_compilation/ufcs.d(47):        the following error occured while looking for a UFCS match
fail_compilation/ufcs.d(47): Error: template `templateF` is not callable using argument types `!()(S)`
    s.templateF();
               ^
fail_compilation/ufcs.d(52):        Candidate is: `templateF()()`
void templateF()();
     ^
fail_compilation/ufcs.d(48): Error: no property `templateO` for `s` of type `S`
    s.templateO();
               ^
fail_compilation/ufcs.d(48):        the following error occured while looking for a UFCS match
fail_compilation/ufcs.d(48): Error: none of the overloads of template `ufcs.templateO` are callable using argument types `!()(S)`
    s.templateO();
               ^
fail_compilation/ufcs.d(54):        Candidates are: `templateO()(int x)`
void templateO()(int x);
     ^
fail_compilation/ufcs.d(55):                        `templateO()(float y)`
void templateO()(float y);
     ^
---
*/

struct S { }

void f()
{
    S s;
    s.regularF();
    s.templateF();
    s.templateO();
}

void regularF();
void templateF()();

void templateO()(int x);
void templateO()(float y);
