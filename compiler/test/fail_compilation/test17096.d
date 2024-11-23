/* TEST_OUTPUT:
---
fail_compilation/test17096.d(77): Error: expected 1 arguments for `isPOD` but had 2
enum b03 = __traits(isPOD, 1, 2);
           ^
fail_compilation/test17096.d(78): Error: expected 1 arguments for `isNested` but had 2
enum b04 = __traits(isNested, 1, 2);
           ^
fail_compilation/test17096.d(79): Deprecation: `traits(isVirtualFunction)` is deprecated. Use `traits(isVirtualMethod)` instead
enum b05 = __traits(isVirtualFunction, 1, 2);
           ^
fail_compilation/test17096.d(79): Error: expected 1 arguments for `isVirtualFunction` but had 2
enum b05 = __traits(isVirtualFunction, 1, 2);
           ^
fail_compilation/test17096.d(80): Error: expected 1 arguments for `isVirtualMethod` but had 2
enum b06 = __traits(isVirtualMethod, 1, 2);
           ^
fail_compilation/test17096.d(81): Error: expected 1 arguments for `isAbstractFunction` but had 2
enum b07 = __traits(isAbstractFunction, 1, 2);
           ^
fail_compilation/test17096.d(82): Error: expected 1 arguments for `isFinalFunction` but had 2
enum b08 = __traits(isFinalFunction, 1, 2);
           ^
fail_compilation/test17096.d(83): Error: expected 1 arguments for `isOverrideFunction` but had 2
enum b09 = __traits(isOverrideFunction, 1, 2);
           ^
fail_compilation/test17096.d(84): Error: expected 1 arguments for `isStaticFunction` but had 2
enum b10 = __traits(isStaticFunction, 1, 2);
           ^
fail_compilation/test17096.d(85): Error: expected 1 arguments for `isRef` but had 2
enum b11 = __traits(isRef, 1, 2);
           ^
fail_compilation/test17096.d(86): Error: expected 1 arguments for `isOut` but had 2
enum b12 = __traits(isOut, 1, 2);
           ^
fail_compilation/test17096.d(87): Error: expected 1 arguments for `isLazy` but had 2
enum b13 = __traits(isLazy, 1, 2);
           ^
fail_compilation/test17096.d(88): Error: expected 1 arguments for `identifier` but had 2
enum b14 = __traits(identifier, 1, 2);
           ^
fail_compilation/test17096.d(89): Error: expected 1 arguments for `getProtection` but had 2
enum b15 = __traits(getProtection, 1, 2);
           ^
fail_compilation/test17096.d(90): Error: expected 1 arguments for `parent` but had 2
enum b16 = __traits(parent, 1, 2);
           ^
fail_compilation/test17096.d(91): Error: expected 1 arguments for `classInstanceSize` but had 2
enum b17 = __traits(classInstanceSize, 1, 2);
           ^
fail_compilation/test17096.d(92): Error: expected 1 arguments for `allMembers` but had 2
enum b18 = __traits(allMembers, 1, 2);
           ^
fail_compilation/test17096.d(93): Error: expected 1 arguments for `derivedMembers` but had 2
enum b19 = __traits(derivedMembers, 1, 2);
           ^
fail_compilation/test17096.d(94): Error: expected 1 arguments for `getAliasThis` but had 2
enum b20 = __traits(getAliasThis, 1, 2);
           ^
fail_compilation/test17096.d(95): Error: expected 1 arguments for `getAttributes` but had 2
enum b21 = __traits(getAttributes, 1, 2);
           ^
fail_compilation/test17096.d(96): Error: expected 1 arguments for `getFunctionAttributes` but had 2
enum b22 = __traits(getFunctionAttributes, 1, 2);
           ^
fail_compilation/test17096.d(97): Error: expected 1 arguments for `getUnitTests` but had 2
enum b23 = __traits(getUnitTests, 1, 2);
           ^
fail_compilation/test17096.d(98): Error: expected 1 arguments for `getVirtualIndex` but had 2
enum b24 = __traits(getVirtualIndex, 1, 2);
           ^
fail_compilation/test17096.d(99): Error: a single type expected for trait pointerBitmap
enum b25 = __traits(getPointerBitmap, 1, 2);
           ^
---
*/
enum b03 = __traits(isPOD, 1, 2);
enum b04 = __traits(isNested, 1, 2);
enum b05 = __traits(isVirtualFunction, 1, 2);
enum b06 = __traits(isVirtualMethod, 1, 2);
enum b07 = __traits(isAbstractFunction, 1, 2);
enum b08 = __traits(isFinalFunction, 1, 2);
enum b09 = __traits(isOverrideFunction, 1, 2);
enum b10 = __traits(isStaticFunction, 1, 2);
enum b11 = __traits(isRef, 1, 2);
enum b12 = __traits(isOut, 1, 2);
enum b13 = __traits(isLazy, 1, 2);
enum b14 = __traits(identifier, 1, 2);
enum b15 = __traits(getProtection, 1, 2);
enum b16 = __traits(parent, 1, 2);
enum b17 = __traits(classInstanceSize, 1, 2);
enum b18 = __traits(allMembers, 1, 2);
enum b19 = __traits(derivedMembers, 1, 2);
enum b20 = __traits(getAliasThis, 1, 2);
enum b21 = __traits(getAttributes, 1, 2);
enum b22 = __traits(getFunctionAttributes, 1, 2);
enum b23 = __traits(getUnitTests, 1, 2);
enum b24 = __traits(getVirtualIndex, 1, 2);
enum b25 = __traits(getPointerBitmap, 1, 2);
