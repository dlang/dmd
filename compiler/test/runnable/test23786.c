// https://issues.dlang.org/show_bug.cgi?id=23768

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

void test23768()
{
    S data = (S) {
      {{.f = {.o = 3}}}
    };
    __check(data.f.o == 3);
    S s;
    s.f.o = 4;
    __check(s.f.o == 4);
}

/**************************/
// https://issues.dlang.org/show_bug.cgi?id=24026

struct A
{
    int type;
};

struct E
{
    struct A action;
};

void test24026()
{
    struct E entry = {{ .type = 1 }};
    __check(entry.action.type == 1);
}

/**************************/

int main()
{
    test23768();
    test24026();
    return 0;
}
