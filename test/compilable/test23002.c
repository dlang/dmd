/* https://issues.dlang.org/show_bug.cgi?id=23002
 */

typedef int x;
struct S { x x; };
struct T { x *x; };
union U { x x; };
