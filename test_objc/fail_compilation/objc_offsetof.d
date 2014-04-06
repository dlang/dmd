/*
TEST_OUTPUT:
---
fail_compilation/objc_offsetof.d(17): Error: .offsetof (obj.member) is not available for members of Objective-C classes (ObjcOffsetof)
fail_compilation/objc_offsetof.d(18): Error: .offsetof (member) is not available for members of Objective-C classes (ObjcOffsetof)
---
*/

extern (Objective-C) class ObjcOffsetof
{
    int member;
}

void main ()
{
    ObjcOffsetof obj;
    auto o = obj.member.offsetof;
    o = ObjcOffsetof.member.offsetof;
}