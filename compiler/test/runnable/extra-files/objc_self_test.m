#import <Foundation/Foundation.h>

@interface objc_self_test : NSObject
-(int) getValue;
@end

@implementation objc_self_test
-(int) getValue
{
    return 3;
}
@end

int getValue ()
{
    return [[[objc_self_test alloc] init] getValue];
}
