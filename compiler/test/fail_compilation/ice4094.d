/*
TEST_OUTPUT:
---
fail_compilation/ice4094.d(15): Error: circular reference to variable `ice4094.Zug!0.Zug.bahn`
    const bahn = Bug4094!(0).hof.bahn;
                 ^
fail_compilation/ice4094.d(23): Error: template instance `ice4094.Zug!0` error instantiating
const a = Zug!(0).bahn;
          ^
---
*/
// REQUIRED_ARGS: -d
struct Zug(int Z)
{
    const bahn = Bug4094!(0).hof.bahn;
}

struct Bug4094(int Q)
{
    Zug!(0) hof;
}

const a = Zug!(0).bahn;
