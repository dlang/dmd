/* TEST_OUTPUT:
---
fail_compilation/test23037.c(101): Error: type-specifier missing for declaration of `a`
fail_compilation/test23037.c(102): Error: type-specifier omitted for declaration of `b`
fail_compilation/test23037.c(103): Error: type-specifier is missing
fail_compilation/test23037.c(104): Error: type-specifier is missing
fail_compilation/test23037.c(105): Error: type-specifier is missing
fail_compilation/test23037.c(106): Error: type-specifier is missing
fail_compilation/test23037.c(201): Error: no type-specifier for parameter
fail_compilation/test23037.c(202): Error: no type-specifier for struct member
fail_compilation/test23037.c(203): Error: type-specifier omitted before declaration of `x`
fail_compilation/test23037.c(204): Error: type-specifier omitted for parameter `x`
fail_compilation/test23037.c(205): Error: type-specifier omitted before bit field declaration of `x`
fail_compilation/test23037.c(206): Error: expected identifier for declarator
fail_compilation/test23037.c(206): Error: expected identifier for declaration
fail_compilation/test23037.c(207): Error: no type-specifier for declarator
fail_compilation/test23037.c(207): Error: expected identifier for declarator
fail_compilation/test23037.c(207): Error: expected identifier for declaration
---
*/

/* https://issues.dlang.org/show_bug.cgi?id=23037
 */

#line 100

const a;
const b = 1;
int c = sizeof(const);
int d = (const)0;
int *e = (const*)0;
enum E : const { ee=1, };

#line 200

void fn1(const);
struct { const : 1; } s1;
struct { const x; } s2;
void fn2(const x) {}
struct { const x : 1; } s3;
const fn3();
const arr[1];
