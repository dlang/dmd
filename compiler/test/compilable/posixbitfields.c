// DISABLED: win32 win64

// https://issues.dlang.org/show_bug.cgi?id=23427

_Static_assert(sizeof(unsigned) == 4, "1");

struct A {
    unsigned x :8;
    unsigned y :4;
    unsigned z :20;
};
_Static_assert(sizeof(struct A)==4, "2");

struct B {
    unsigned x :4;
    unsigned y :2;
    unsigned z :26;
};
_Static_assert(sizeof(struct B)==4, "3");

struct C {
    unsigned x :4;
    unsigned y :4;
    unsigned z :24;
};
_Static_assert(sizeof(struct C)==4, "4"); // This one fails


_Static_assert(sizeof(struct {
    unsigned a: 1;
    unsigned b: 7;
    unsigned c: 24;
}) == sizeof(unsigned), "1 7 24");

_Static_assert(sizeof(struct {
    unsigned a: 2;
    unsigned b: 6;
    unsigned c: 24;
}) == sizeof(unsigned), "2 6 24");

_Static_assert(sizeof(struct {
    unsigned a: 3;
    unsigned b: 5;
    unsigned c: 24;
}) == sizeof(unsigned), "3 5 24");

_Static_assert(sizeof(struct {
    unsigned a: 4;
    unsigned b: 4;
    unsigned c: 24;
}) == sizeof(unsigned), "4 4 24");

_Static_assert(sizeof(struct {
    unsigned a: 5;
    unsigned b: 3;
    unsigned c: 24;
}) == sizeof(unsigned), "5 3 24");

_Static_assert(sizeof(struct {
    unsigned a: 6;
    unsigned b: 2;
    unsigned c: 24;
}) == sizeof(unsigned), "6 2 24");

_Static_assert(sizeof(struct {
    unsigned a: 7;
    unsigned b: 1;
    unsigned c: 24;
}) == sizeof(unsigned), "7 1 24");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 9;
    unsigned c: 15;
}) == sizeof(unsigned), "8 9 15");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 10;
    unsigned c: 14;
}) == sizeof(unsigned), "8 10 14");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 11;
    unsigned c: 13;
}) == sizeof(unsigned), "8 11 13");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 12;
    unsigned c: 12;
}) == sizeof(unsigned), "8 12 12");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 13;
    unsigned c: 11;
}) == sizeof(unsigned), "8 13 11");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 14;
    unsigned c: 10;
}) == sizeof(unsigned), "8 14 10");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 15;
    unsigned c: 9;
}) == sizeof(unsigned), "8 15 9");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 16;
    unsigned c: 8;
}) == sizeof(unsigned), "8 16 8");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 17;
    unsigned c: 7;
}) == sizeof(unsigned), "8 17 7");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 18;
    unsigned c: 6;
}) == sizeof(unsigned), "8 18 6");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 19;
    unsigned c: 5;
}) == sizeof(unsigned), "8 19 5");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 20;
    unsigned c: 4;
}) == sizeof(unsigned), "8 20 4");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 21;
    unsigned c: 3;
}) == sizeof(unsigned), "8 21 3");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 22;
    unsigned c: 2;
}) == sizeof(unsigned), "8 22 2");

_Static_assert(sizeof(struct {
    unsigned a: 8;
    unsigned b: 23;
    unsigned c: 1;
}) == sizeof(unsigned), "8 23 1");
