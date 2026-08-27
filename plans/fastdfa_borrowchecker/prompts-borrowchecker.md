## DeepSeek V4 flash

> > You are researching the future implementation of a borrow checker in the fast dfa engine.
> There is some support as part of escape analysis, specifically the ability to represent the borrow-from-owner relationship strength.
> However the relationships between DFAVar* and DFAObject* is a many to many one.
> We need an efficient way of detecting if the object has been borrowed from, or is a borrow.
> So we can enable the borrow checkers protections.
> We may place some minor restrictions on borrows, i.e. no assignments for borrows that live outside a loop.
> The primary restrictions when a borrow has occured is that the owner cannot be mutated and it must outlive the borrow.
> It is triggered typically from a function call I.e. (the syntax isn't part of scope right now):
> int* borrow() @escape(return^)
> For now we'll use a UDA __fastdfa_returnborrow

> When placed on the function it refers to the this parameter, otherwise it'll be placed on a parameter.

> Depth based may work?, BUT after a borrow has ended, that owner must be seen as no longer having borrows.
> If a new borrow takes place, that one must be seen instead.

> Reassignment of a borrow variable (b = something else while b is an active borrow) is banned outside of loops; inside loops it is allowed. The same-var replace/remove semantics I proposed for the registry then only kicks in for loop-scoped borrows.

> No new files are required for this, existing tests are sufficient
> To run the tests use: C:\Program Files\Git\bin\bash.exe testdfa/run.sh
> wrong test: int* f(ref int x) @__fastdfa_returnborrow { return &x; }
> should be: int* f(@__fastdfa_returnborrow ref int x) { return &x; }
> Same-scope declaration order is ok as long as it isn't a struct with a destructor. This should already be handled in the variable declaration lifetime and general compiler scoping rules for variables.
> Field/pointer-indirection borrow sources needs to register, do not change existing rules, add additive rules that cover just the borrow checker.
> Borrows of borrowed values are treated as borrows of the original cell, wrong it should be from the borrowed value one level deep. The extra indirection should be handled automatically transitively

> Borrows stored through a dereference is fine for @system, but not @safe code, the report.d error function for this scenario will need to check for safety
> Union semantics inside loops what? No.
> For loops we only need to prevent changing borrows that are in variables declared outside of the loop.
> int* borrow = ...; for(;;) borrow = null; // error

> Mutation of the owner through a function call, nope, needs to be checked to make sure parameter is const/immutable

> Test needs to include a check to make sure that the owner can be a struct, it won't have a DFAObject* associated with it, only the cell of the variable.

> multiple borrows from an owner is ok

> Just use the test script I told you to.
> To run the tests use: C:\Program Files\Git\bin\bash.exe testdfa/run.sh

> __fastdfa_returnborrow should be an enum not a struct: enum __fastdfa_returnborrow;
> The logic of detecting it will happen in two places in utils.d ensureDFAParameters and ensureDFAParameter.

> Note: you can use testdfa/start.d instead of the other test files and then enable the exit 0
> this will give you a mini test file that won't have other stuff in it.

> Note: there is a way to turn on the built in logging, with debugStructure

> Oh hold on, start.d is wrong its startd.d

> ya know this debugging would go a lot faster if you turned on debugStructure and debugIt with a restriction in entry.d (commented out line 103) to only analyze a single function.

> ok for the most part the borrow checker is working, except one specific case.
> The pattern of borrowErr1 should be ok.
> The mutation is not on the cell storage for the int, which the taking of reference is to.
> Mutating the integer value which is a basic type, won't invalidate the borrow b.

> null this pointer for isConst expression.d line 2539

> Your new function checkBorrowArgument should be handled as part of argument convergance in analysis.d

> src\dmd\dfa\fast\analysis.d(1242): Error: no property `nextOf` for `(*argListItem).paramType` of type `dmd.mtype.Type`

> This error message isn't correct.
> testdfa\startd.d(393): Error: Cannot mutate the owner of an active borrow
> p = null; // error: reassigning a reference-type owner of an active borrow
> testdfa\startd.d(392):        Borrowed here
> int** b = borrowFn2(&p);
> testdfa\startd.d(392):        For variable `b`
> int** b = borrowFn2(&p);
> At no point is p referenced.

> Verify if you have a struct or a class, with a method that the borrow checker will fire. Free-functions are not the primary use case.

> Modify test/compilable/fastdfa.d and test/fails_compilation/fastdfa.d with their respective tests from start.d

> Add the enum __fastdfa_returnborrow to druntime/src/core/attribute.d make sure to add a comment that makes it clear that it is an experimental feature that may be removed at a later date.
> Write the changelog entry in changelog (.dd)

> Verify: when you borrow from a class, the owner object must outlive the borrow.

> Add test case to startd.d and run the run.sh script

> Nevermind it fires now, I undid a change I made

> No. Enable logging, add entry point blocking then run run.sh
> If you call a method, the this pointer should become non-null with a DFAObject allocated for it.

> The way you went about solving this isn't right, when you dereference you create a child of the DFAVar, that is a derefence var, you need to go peeking by walking the DFAVar's to find which DFAObject* the this pointer is

> walkRoots doesn't sound right either, there are walks that are indirection aware

> Add the test case.
