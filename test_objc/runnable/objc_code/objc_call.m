
#import <Foundation/Foundation.h>

id testIMP(id self, SEL _cmd) {
	return self;
}

id callIMP(IMP imp) {
	id (*impCall)(id, SEL) = (id (*)(id, SEL))imp;
	return impCall([NSObject class], @selector(description));
}
