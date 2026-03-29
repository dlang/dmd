/*
TEST_OUTPUT:
---
fail_compilation/ice4094.d(13): Error: circular reference to variable `ice4094.Zug!0.Zug.bahn`
fail_compilation/ice4094.d(13):        while resolving `ice4094.Zug!0.Zug.bahn`
fail_compilation/ice4094.d(21):        while resolving `ice4094.a`
fail_compilation/ice4094.d(21): Error: template instance `ice4094.Zug!0` error instantiating
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
