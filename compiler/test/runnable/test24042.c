// https://issues.dlang.org/show_bug.cgi?id=24031

#include <assert.h>

struct ES {
    struct {
        char data[24];
    };
    int length;
};

struct ES empty = {.data = {1}, .length = 2};

int main()
{
    assert(empty.data[0] == 1);
    assert(empty.length == 2);
    return 0;
}
