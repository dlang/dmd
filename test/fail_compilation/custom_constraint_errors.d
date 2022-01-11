/*
TEST_OUTPUT:
---
fail_compilation/custom_constraint_errors.d(27): Error: template `custom_constraint_errors.foo` cannot deduce function from argument types `!()(long)`
fail_compilation/custom_constraint_errors.d(23):        Candidate is: `foo(T)(T arg)`
  with `T = long`
  must satisfy the following constraint:
`       isSmallEnough!T: long must be smaller or equal than 4 bytes`
---
*/

struct ConstraintInfo {
	bool matches;
	string errorMessage;

	bool opCast() const { return matches; }
	string toString() const { return errorMessage; }
}

enum ConstraintInfo isSmallEnough(T) = ConstraintInfo(T.sizeof <= 4,
	T.stringof ~ " must be smaller or equal than 4 bytes");

void foo(T)(T arg) if (isSmallEnough!T) {}

void main() {
	foo(4);
	foo(long(4));
}
