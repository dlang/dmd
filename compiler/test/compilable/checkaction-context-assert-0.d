module checkaction_context_assert_0;
/*
REQUIRED_ARGS: -vcg-ast -o- -checkaction=context
OUTPUT_FILES: compilable/checkaction-context-assert-0.d.cg
TEST_OUTPUT_FILE: extra-files/checkaction-context-assert-0.d.cg
*/

void a() { assert(0); }
void b() { assert(false); }
void c() { assert(null); }
