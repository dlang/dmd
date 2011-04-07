// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() [alloc];
	NSObject init() [init];
}

void main() {
	NSObject obj1 = NSObject.alloc().init();
	assert(obj1 !is null);
}