
extern extern (Objective-C)
class NSObject {
	static NSObject alloc();
	static NSObject allocWithZone(void* zone);
}

void main() {
	NSObject obj1 = NSObject.alloc();
	NSObject obj2 = NSObject.allocWithZone(null);
}