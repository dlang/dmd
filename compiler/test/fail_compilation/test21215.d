/* TEST_OUTPUT:
---
fail_compilation/test21215.d(14): Error: named arguments not allowed here
fail_compilation/test21215.d(19): Error: named arguments not allowed here
fail_compilation/test21215.d(23): Error: named arguments not allowed here
fail_compilation/test21215.d(24): Error: named arguments not allowed here
fail_compilation/test21215.d(28): Error: named arguments not allowed here
---
*/
struct S { int x; }

void test() {
	auto s = S(
		y:
    1
	);

  auto s2 = S(
    x: 1
  );

  auto s3 = S(
    x: 1,
    y: 2
  );

  auto s4 = S(
    yashu:
    
    2
  );
}