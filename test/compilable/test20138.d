alias C = const int;
static assert(is(shared(C) U == shared U) && is(U == C));
static assert(is(shared(C) == shared U, U) && is(U == C));


alias I = inout int;
static assert(is(shared(I) U == shared U) && is(U == I));
static assert(is(shared(I) == shared U, U) && is(U == I));

alias IC = inout const int;
static assert(is(shared(IC) U == shared U) && is(U == IC));
static assert(is(shared(IC) == shared U, U) && is(U == IC));
