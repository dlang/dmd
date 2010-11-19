
// Minimal runtime for unit tests

#import <Foundation/Foundation.h>

id _dobjc_class(id obj) {
    return [objc class];
}

id _dobjc_casttoclass(id obj, Class cls) {
    if ([obj isKindOfClass:cls])
        return obj;
    return nil;
}

id _dobjc_casttointerface(id obj, Protocol *p) {
    if ([obj conformsToProtocol:p])
        return obj;
    return nil;
}