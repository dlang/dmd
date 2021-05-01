#import <Foundation/Foundation.h>

@protocol Foo
+(int) classMethod:(int)a;
-(int) instanceMethod:(int)a;
@end

int callFooInstanceMethod(id<Foo> foo, int a)
{
    return [foo instanceMethod: a];
}

int callFooClassMethod(id<Foo> foo, int a)
{
    return [[foo class] classMethod: a];
}
