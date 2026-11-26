struct Inner { int arr[3]; };
struct Outer { struct Inner inr; };

struct Outer a = { .inr.arr[0] = 11 };
struct Outer b = { .inr.arr[1] = 22 };
