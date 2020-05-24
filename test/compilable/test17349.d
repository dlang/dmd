
/* REQUIRED_ARGS:
   PERMUTE_ARGS:
 */

// https://issues.dlang.org/show_bug.cgi?id=16538

const(int) retConst1() @system;
int retConst2() @system;
auto retConst = [&retConst1, &retConst2];

const(int*) retConstPtr1() @system;
const(int)* retConstPtr2() @system;
auto retConstPtr = [&retConstPtr1, &retConstPtr2];

void constArray1(const(int)[1]) @system;
void constArray2(const(int[1])) @system;
auto constArray = [&constArray1, &constArray2];

const(int)[] retConstSlice1() @system;
const(int[]) retConstSlice2() @system;
auto retConstSlice = [&retConstSlice1, &retConstSlice2];

void constSlice1(const(int)[]) @system;
void constSlice2(const(int[])) @system;
auto constSlice = [&constSlice1, &constSlice2];

void ptrToConst1(const(int)*) @system;
void ptrToConst2(const(int*)) @system;
auto ptrToConst = [&ptrToConst1, &ptrToConst2];
