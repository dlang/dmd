// REQUIRED_ARGS: -w -vcolumns -unittest

/*
TEST_OUTPUT:
---
fail_compilation/more_moves.d(27,12): Error: struct `more_moves.S` is not copyable because it is annotated with `@disable`
fail_compilation/more_moves.d(33,9): Error: struct `more_moves.S` is not copyable because it is annotated with `@disable`
---
*/

@safe:

// uint postblit;                  // number of calls made to `S.this(this)`

struct S
{
@safe:
    @disable this(this);
    //this(this) { postblit += 1; }
    // TODO include copy constructor
    int x;
    alias x this;
}

S moveSingleReturn(S e, int x)
{
    return e;                   // move is now enabled
}

S moveAssignment(S e, int x)
{
    S f;
    f = e;                      // TODO: enable move here
}

// S moveSingleReturnAlreadyMovedInAssignment(S e, int x)
// {
//     S f;
//     f = e;                   // TODO: enable move here
//     return e;                // TODO: error, already moved, give location of move
// }

// S moveSingleReturnAlreadyMovedInInit(S e, int x)
// {
//     S f = e;                 // TODO: enable move here
//     return e;                // TODO: error, already moved, give location of move
// }

// @safe unittest
// {
//     testAA(S.init);
//     assert(postblit == 0);

//     testC(S.init);
//     assert(postblit == 0);
// }

// S testAA(S e)
// {
//     return moveSingleReturn(e, 1);         // TODO: moved
// }

// S testC(S e)
// {
//     auto f = e;                 // single ref of `e` can be moved to `f`
//     return f;                   // single ref of `f` can be moved
// }

// S testMM(S e, int x)
// {
//     if (x == 1)
//         return e;               // moved
//     else
//         return e;               // moved
// }

// S testME(S e, int x)
// {
//     if (x == 1)
//         return e;               // moved
//     return e;                   // moved
// }

// S testV(S e)
// {
//     S f;
//     f = e;                      // single ref of `e` can be moved to `f`
//     return f;                   // single ref of `f` can be moved
// }

// S testAAA(S e)
// {
//     return (e.x == 0 ?
//             moveSingleReturn(e, 1) :       // TODO: moved
//             moveSingleReturn(e, 1));       // TODO: moved
// }

// // TODO: Detect cases:
// // each VarExp of `e` must be either
// // - reads of members (`DotVarExp` where e1 is `e`)
// // - pass by move in return statement
// // - final assignment
// S testB(S e)
// {
//     if (e.x == 0)               // member read ok
//         return moveSingleReturn(e, 1);     // parameter can be passed by move
//     return moveSingleReturn(e, 1);         // parameter can be passed by move
// }

// struct A
// {
//     this(S e)
//     {
//         this.e = e; // last ref so `e` can be moved
//     }
//     S e;
// }

// S testD(S e)
// {
//     auto f = e;                 // can't move `e`
//     auto g = e;                 // can't move `e`
//     return f;                   // can move `f`
// }

// // Can move e because all refs to `e` are direct returns.
// S testE(S e)
// {
//     if (true)
//         return e;               // first ref of `e` is moved
//     else
//         return e;               // second ref of `e` is moved
// }

// S testF(S e)
// {
//     auto f = e;                 // can't move `e`
//     if (e.x == 0)
//         return e;               // can't move `e`
//     else if (e.x == 1)
//         return e;               // can't move `e`
//     else
//         return f;               // can move `f`
// }
