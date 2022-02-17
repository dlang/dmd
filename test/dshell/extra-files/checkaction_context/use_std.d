// Tests for missing instances referenced by bigger projects (== Phobos)
// More of a canary because the template emission is rather flaky

module use_std;

import std;

void main()
{
    // https://issues.dlang.org/show_bug.cgi?id=22374
    assert(0);

    // https://issues.dlang.org/show_bug.cgi?id=19937
    wchar[] c;
    toUTF8(c);

    parseJSON(`[ "abc", "def", "ghi" ]`);
}
