// REQUIRED_ARGS: -w -o-

alias noreturn = typeof(*null);


/++
TEST_OUTPUT:
---
fail_compilation/noreturn3.d(106): Error: none of the overloads of `callback` are callable using argument types `(void function() pure nothrow @nogc @safe)`
fail_compilation/noreturn3.d(101):        Candidates are: `noreturn3.callback(noreturn function() f)`
fail_compilation/noreturn3.d(102):                        `noreturn3.callback(noreturn delegate() dg)`
fail_compilation/noreturn3.d(109): Error: none of the overloads of `callback` are callable using argument types `(void delegate() pure nothrow @nogc @safe)`
fail_compilation/noreturn3.d(101):        Candidates are: `noreturn3.callback(noreturn function() f)`
fail_compilation/noreturn3.d(102):                        `noreturn3.callback(noreturn delegate() dg)`
---
+/
#line 100

void callback(noreturn function() f);
void callback(noreturn delegate() dg);

void useCallback()
{
    callback(() {});

    int res;
    callback(() {
        res++;
    });
}

/++
TEST_OUTPUT:
---
fail_compilation/noreturn3.d(206): Error: `noreturn3.callbackVP` called with argument types `(int* function() pure nothrow @nogc @safe)` matches both:
fail_compilation/noreturn3.d(201):     `noreturn3.callbackVP(void* function() f)`
and:
fail_compilation/noreturn3.d(202):     `noreturn3.callbackVP(void* delegate() dg)`
fail_compilation/noreturn3.d(208): Error: `noreturn3.callbackVP` called with argument types `(noreturn* function() pure nothrow @nogc @safe)` matches both:
fail_compilation/noreturn3.d(201):     `noreturn3.callbackVP(void* function() f)`
and:
fail_compilation/noreturn3.d(202):     `noreturn3.callbackVP(void* delegate() dg)`
---
+/
#line 200

int callbackVP(void* function() f);
void* callbackVP(void* delegate() dg);

void useCallback2()
{
    callbackVP(() => (int*).init);

    callbackVP(() => (noreturn*).init);
}

/++
TEST_OUTPUT:
---
fail_compilation\noreturn3.d(306): Error: `noreturn3.callback3` called with argument types `(noreturn function() pure nothrow @nogc @safe)` matches both:
fail_compilation\noreturn3.d(301):     `noreturn3.callback3(void function() f)`
and:
fail_compilation\noreturn3.d(302):     `noreturn3.callback3(void delegate() dg)`
---
+/
#line 300

int callback3(void function() f);
void* callback3(void delegate() dg);

void useCallback3()
{
    callback3(() => assert(0));
}
