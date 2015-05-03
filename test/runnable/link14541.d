import imports.link14541traits;

void main()
{
    Tuple!(int, int) result;

    alias T = typeof(result);
    static assert(hasElaborateAssign!T);
    // hasElablrateAssign!(Tuple(int, int)):
    // 1. instantiates Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = Rvalue]
    //    2. instantiates swap!(Tuple!(int, int))
    //       3. instantiates hasElablrateAssign!(Tuple!(int, int))
    //          --> forward reference error
    //       --> swap!(Tuple!(int, int)) fails to instantiate
    //    --> Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = rvalue] fails to instantiate
    // 4. instantiates Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = Lvalue]
    //    --> succeeds
    // hasElablrateAssign!(Tuple(int, int)) succeeds to instantiate (result is 'true')

    // Instantiates Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = Rvalue], but
    // it's already done in gagged context, so this is made an error reproduction instantiation.
    // --> 1st error reproduction instantiation
    // But, the forward reference of hasElablrateAssign!(Tuple(int, int)) is alredy resolved, so
    // the instantiation will succeeds.
    result = Tuple!(int, int)(0, 0);

    // Instantiates Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = Rvalue], but
    // it's already done in gagged context, so this is made an error reproduction instantiation.
    // --> 2nd error reproduction instantiation
    // But, the forward reference of hasElablrateAssign!(Tuple(int, int)) is alredy resolved, so
    // the instantiation will succeeds.
    result = Tuple!(int, int)(0, 0);

    // The two error reproduction instantiations generate the function:
    //   Tuple!(int, int).opAssign!(Tuple!(int, int)) [auto ref = Rvalue]
    // twice, then it will cause duplicate COMDAT error in Win64 platform.
}
