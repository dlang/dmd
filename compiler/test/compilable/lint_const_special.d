/*
REQUIRED_ARGS: -w
TEST_OUTPUT:
---
compilable/lint_const_special.d(26): Lint: special method `opEquals` should be marked as `const`
    bool opEquals(ref const BadStruct rhs) {
         ^
compilable/lint_const_special.d(31): Lint: special method `toHash` should be marked as `const`
    hash_t toHash() {
           ^
compilable/lint_const_special.d(36): Lint: special method `opCmp` should be marked as `const`
    int opCmp(ref const BadStruct rhs) {
        ^
compilable/lint_const_special.d(41): Lint: special method `toString` should be marked as `const`
    string toString() {
           ^
---
*/

// Enable our new lint rule for the file
pragma(lint, constSpecial):

struct BadStruct
{
    // LINT: special method `opEquals` should be marked as `const`
    bool opEquals(ref const BadStruct rhs) {
        return true;
    }

    // LINT: special method `toHash` should be marked as `const`
    hash_t toHash() {
        return 0;
    }

    // LINT: special method `opCmp` should be marked as `const`
    int opCmp(ref const BadStruct rhs) {
        return 0;
    }

    // LINT: special method `toString` should be marked as `const`
    string toString() {
        return "BadStruct";
    }
}

struct GoodStruct
{
    // OK: method is marked as const
    bool opEquals(ref const GoodStruct rhs) const {
        return true;
    }

    // OK: method is marked as const
    hash_t toHash() const {
        return 1;
    }

    // OK: method is marked as const
    int opCmp(ref const GoodStruct rhs) const {
        return 0;
    }

    // OK: method is marked as const
    string toString() const {
        return "GoodStruct";
    }
}

// Disable the linter for the following code
pragma(lint, none):

struct IgnoredStruct
{
    // No lint messages here, as the linter is disabled!
    bool opEquals(ref const IgnoredStruct rhs) {
        return true;
    }
}

void main()
{
}
