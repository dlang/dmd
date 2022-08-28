// EXTRA_OBJC_SOURCES:
// REQUIRED_ARGS: -L-lobjc

// This file verifies that Objective-C protocols are put in the correct segments
// and sections in the binary. If not, functions from the Objective-C runtime
// won't find the protocol data and the below functions will return `null`.

import core.attribute : selector, optional;

extern (Objective-C):

struct Protocol;
struct objc_selector;
alias SEL = objc_selector*;

struct objc_method_description
{
    SEL name;
    char* types;

    /**
     * Returns `true` if the method description is valid.
     *
     * That means that the Objective-C runtime was able to find the method. That
     * implicitly means that the protocol data has been laid out correctly in the
     * binary.
     */
    bool isValid()
    {
        return name && types;
    }
}

SEL sel_registerName(in char* str);
Protocol* objc_getProtocol(in char* name);
objc_method_description protocol_getMethodDescription(
    Protocol* proto, SEL aSel, bool isRequiredMethod, bool isInstanceMethod
);

interface Foo
{
    void foo1() @selector("foo1");
    static void foo2() @selector("foo2");
    @optional void foo3() @selector("foo3");
    @optional static void foo4() @selector("foo4");
}

// A class that implements an Objective-C interface is required for the
// protocol data to be put into the binary.
class TestObject : Foo
{
    void foo1() @selector("foo1") {}
    static void foo2() @selector("foo2") {}
    void foo3() @selector("foo3") {}
    static void foo4() @selector("foo4") {}
}

extern (D):

/// Used to indicate if a method is an instance method or a class (static) method.
enum MethodType : bool
{
    class_,
    instance
}

/// Used to indicate if a method is required or optional.
enum MethodFlag : bool
{
    optional,
    required
}

/**
 * Returns the method description for the method with the given selector.
 *
 * The protocol the methods will be looked up in is always `Foo`.
 *
 * Params:
 *  selector = the selector of the method
 *  flag = indicates if the method is required or optional
 *  type = indicates if the method is an instance method or a class method
 */
objc_method_description methodDescription(in char* selector, MethodFlag flag, MethodType type)
{
    auto protocol = objc_getProtocol("Foo");
    assert(protocol);

    auto sel = sel_registerName(selector);
    assert(sel);

    return protocol_getMethodDescription(protocol, sel, flag, type);
}

void main()
{
    with (MethodFlag) with (MethodType)
    {
        assert(methodDescription("foo1", required, instance).isValid);
        assert(methodDescription("foo2", required, class_).isValid);
        assert(methodDescription("foo3", optional, instance).isValid);
        assert(methodDescription("foo4", optional, class_).isValid);
    }
}
