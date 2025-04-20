/* TEST_OUTPUT:
---
fail_compilation/test21215.d(14): Error: `y` is not a member of `S`
fail_compilation/test21215.d(19): Error: `xhs` is not a member of `S`, did you mean variable `xsh`?
fail_compilation/test21215.d(31): Error: too many initializers for `S` with 1 field
fail_compilation/test21215.d(37): Error: `y` is not a member of `S`
fail_compilation/test21215.d(41): Error: `yashu` is not a member of `S`
---
*/
struct S { int xsh; }

void test() {
	auto s = S(
		y:
    1
	);

  auto s3 = S(
    xhs:
    1
  );

  auto s4 = S(
    xsh: 1
  );

  auto s5 = S(
    xsh:
    1,

    xsh:
    1
  );

  auto s6 = S(
    xsh: 1,
    y: 2
  );

  auto s7 = S(
    yashu:
    
    2
  );
}