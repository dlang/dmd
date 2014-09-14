
#import <Foundation/Foundation.h>

void test_throw() {
    @throw [NSException exceptionWithName:@"D_Test" reason:@"Need testing" userInfo:nil];
}

BOOL test_catch(void (*test)()) {
    @try {
        test();
    }
    @catch (NSException * e) {
        return YES;
    }
    return NO;
}

void test_finally(void (*test)(), BOOL *passed) {
    *passed = NO;
    @try {
        test();
    }
    @finally {
        *passed = YES;
    }
}