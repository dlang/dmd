/*
TEST_OUTPUT:
---
fail_compilation/fail346.d(23): Error: undefined identifier `P`
        const P T = { val }; // the P here is an error it should be S
                ^
fail_compilation/fail346.d(23): Error: variable `fail346.S.T!0.T` - cannot use template to add field to aggregate `S`
        const P T = { val }; // the P here is an error it should be S
                ^
fail_compilation/fail346.d(28): Error: template instance `fail346.S.T!0` error instantiating
    const R V=R.T!(val);
               ^
fail_compilation/fail346.d(31):        instantiated from here: `V!(S, 0)`
const S x = V!(S,0);
            ^
---
*/

struct S {
    int x;

    template T(int val) {
        const P T = { val }; // the P here is an error it should be S
    }
}

template V(R,int val){
    const R V=R.T!(val);
}

const S x = V!(S,0);
