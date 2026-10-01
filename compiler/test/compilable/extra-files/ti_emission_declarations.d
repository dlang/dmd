// expected: TypeInfo_Struct lazily emitted into an object file referencing it
struct S {
    int x;
}

// expected: TypeInfo_Class (__ClassZ) defined in this object file only, along with the class declaration
class C {
    int x;
}

// expected: TypeInfo_Class (__InterfaceZ) defined in this object file only, along with the interface declaration;
//           TypeInfo_Interface lazily emitted into an object file referencing it
interface I {
    void foo();
}

// expected: TypeInfo_Enum lazily emitted into an object file referencing it
enum E {
    x,
}
