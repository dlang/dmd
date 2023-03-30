/* TEST_OUTPUT:
---
fail_compilation/isexp.d(8): Error: cannot infer parameters for `is` TypeSpecialization when it is an alias template instance
---
*/
alias A(T) = int;
enum ati1 = is(int == A!int);
enum ati2 = is(int == A!T, T); // can't infer
