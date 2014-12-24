#import <Foundation/Foundation.h>

#if __has_feature(objc_nonfragile_abi)
@interface NonFragileBase : NSObject
@property(nonatomic) size_t a;
@end

@implementation NonFragileBase
@end
#endif