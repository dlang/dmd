/*
PERMUTE_ARGS:
REQUIRED_ARGS: -transition=interpolate
TEST_OUTPUT:
---
fail_compilation/istring1.d(16): Error: missing parentheses in interpolated string expression '$(...)'
fail_compilation/istring1.d(23): Error: unfinished interpolated string expression '$(...)'
fail_compilation/istring1.d(26): Error: unfinished interpolated string expression '$'
fail_compilation/istring1.d(29): Error: invalid expression '1 + 2;' inside interpolated string
fail_compilation/istring1.d(32): Error: undefined escape sequence \c
fail_compilation/istring1.d(33): Error: unterminated named entity &quot";
---
*/
enum s1 = i`

    $!

`;
enum s2 = i`

    $(

`;
enum s3 = i`

    $`;
enum s4 = i`

    $(1 + 2;)`;

// Test that bad escape sequences are handled sanely
enum s5 = i"\c";
enum s6 = i"\&quot";
