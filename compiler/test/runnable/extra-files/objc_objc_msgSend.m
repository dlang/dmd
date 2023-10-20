#import <Foundation/Foundation.h>

typedef struct
{
    int a, b, c, d, e;
} Struct;

@interface stret : NSObject
-(Struct) getValue;
@end

@implementation stret
-(Struct) getValue
{
    Struct s = { 3, 3, 3, 3, 3 };
    return s;
}
@end

@interface fp2ret : NSObject
-(_Complex long double) getValue;
@end

@implementation fp2ret
-(_Complex long double) getValue
{
    return 1+3i;
}
@end

@interface fpret : NSObject
-(long double) getValue;
@end

@implementation fpret
-(long double) getValue
{
    return 0.000000000000000002L;
}
@end

@interface float32 : NSObject
-(float) getValue;
@end

@implementation float32
-(float) getValue
{
    return 0.2f;
}
@end

@interface double64 : NSObject
-(double) getValue;
@end

@implementation double64
-(double) getValue
{
    return 0.2;
}
@end
