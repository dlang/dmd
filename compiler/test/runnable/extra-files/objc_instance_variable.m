#import <Foundation/Foundation.h>

@interface Foo : NSObject
{
    // This need to be at least three instance variables of the size of `int`.
    // I'm guessing this is because instance variables start at different
    // offsets in Objective-C and in D.
    @public int a;
    @public int b;
    @public int c;
}
@end

@implementation Foo
@end

int getInstanceVariableC(Foo* foo)
{
    return foo->c;
}

void setInstanceVariables(Foo* foo)
{
    foo->a = 1;
    foo->b = 2;
    foo->c = 3;
}
