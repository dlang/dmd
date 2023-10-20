// https://issues.dlang.org/show_bug.cgi?id=22631

enum E : char { A = 3, B };

_Static_assert(sizeof(enum E) == 1, "1");
_Static_assert(A == 3, "2");


// https://issues.dlang.org/show_bug.cgi?id=22705

enum L: long long {
    L_A = 1,
};

enum U: unsigned long long {
    U_A = 1,
};

enum U2: unsigned {
    U2_A = 1,
};

enum U3: unsigned long {
    U3_A = 1,
};

// https://issues.dlang.org/show_bug.cgi?id=23801

enum
{
    X = ~1ull,
    Y,
};

_Static_assert(X == ~1ull, "3");
_Static_assert(Y == ~1ull + 1, "4");
