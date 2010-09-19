
extern (Objective-C)
class NSObject {
	static NSObject alloc();
	NSObject init() { return null; }
}

void main() {
	NSObject obj1 = NSObject.alloc().init();
	assert(obj1 is null);
}