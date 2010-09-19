
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

void main() {
	NSObject obj1 = NSObject.alloc().init();
	assert(obj1 !is null);
}