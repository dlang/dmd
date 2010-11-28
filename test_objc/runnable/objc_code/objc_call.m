
// Minimal runtime for unit tests

#import <Foundation/Foundation.h>

id _dobjc_class(id obj) {
    return [objc class];
}

id _dobjc_casttoclass(id obj, Class cls) {
    return [obj isKindOfClass:cls] ? obj : nil;
}

id _dobjc_casttointerface(id obj, Protocol *p) {
    return [obj conformsToProtocol:p] ? obj : nil;
}

BOOL _test() {
    return [NSArray class];
}