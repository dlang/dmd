
extern (Objective-C)
interface NSObject {
	static NSObject alloc();
	static NSObject allocWithZone(void* zone);
}


import std.stdio;

void main() {
	NSObject obj1 = NSObject.alloc();
	NSObject obj2 = NSObject.allocWithZone(null);
}