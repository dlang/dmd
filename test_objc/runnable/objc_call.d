
import std.c.stdio;

alias void* id; // untyped Obj-C object pointer

extern (Obj-C)
interface Class {
	NSObject alloc() [alloc];
}

extern (Obj-C)
interface NSObject {
	NSObject initWithUTF8String(in char *str) [initWithUTF8String:];
	void release() [release];
}

extern (C) void NSLog(NSObject, ...);
extern (C) Class objc_lookUpClass(const char* name);
extern (C) id objc_msgSend(id obj, const char* sel);

void main() {
	auto c = objc_lookUpClass("NSString");
	auto o = c.alloc().initWithUTF8String("hello");
	NSLog(o);
	o.release();
}
