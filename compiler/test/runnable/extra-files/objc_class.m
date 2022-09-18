#import <Foundation/Foundation.h>

@interface Foo : NSObject
+(int) classMethod:(int)a;
-(int) instanceMethod:(int)a;
@end

int callFooInstanceMethod(int a)
{
    Foo* foo = [[Foo alloc] init];
    int result = [foo instanceMethod:a];
    [foo release];

    return result;
}

int callFooClassMethod(int a)
{
    return [Foo classMethod: a];
}
