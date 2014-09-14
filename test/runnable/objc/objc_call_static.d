// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern extern (Objective-C)
class NSObject {
	static NSObject alloc() [alloc];
	static NSObject allocWithZone(void* zone) [allocWithZone:];
}

void main() {
	NSObject obj1 = NSObject.alloc();
	NSObject obj2 = NSObject.allocWithZone(null);
}