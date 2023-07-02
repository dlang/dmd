// https://issues.dlang.org/show_bug.cgi?id=23768

#include <assert.h>

typedef struct {
  union {
    struct {
      int o;
    } f;
  };
} T;

void f(void) {
    T data = (T) {
      {.f = {.o = 0}}
    };
}

/***************/

typedef struct {
  union {
    struct {
      struct { double o; } f;
    };
  };
} S;

_Static_assert(sizeof(S) == 8, "1");

int main()
{
    S data = (S) {
      {{.f = {.o = 3}}}
    };
    assert(data.f.o == 3);
    S s;
    s.f.o = 4;
    assert(s.f.o == 4);
    return 0;
}
