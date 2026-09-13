/*
TEST_OUTPUT:
---
---
*/

// Case 1: The Bug (Recursive opCast)
// The compiler should IGNORE this opCast and give the raw pointer
class BadCast {
    BadCast opCast(T)() {
        return this;
    }
}

void testRegression() {
    BadCast c = new BadCast();
    
    // This used to fail compilation
    void* ptr = cast(void*)c;
    
    // Verify we actually got a pointer
    assert(ptr !is null);
    assert(ptr is cast(void*)c);
}

// Case 2: The Valid Use (opCast returns void*)
// The compiler should RESPECT this opCast
class GoodCast {
    int x;
    void* opCast(T : void*)() {
        return &x;
    }
}

void testValid() {
    GoodCast c = new GoodCast();
    void* ptr = cast(void*)c;
    
    // Verify it called opCast (ptr should point to 'x', not the class header)
    assert(ptr == &c.x); 
}

void main() {
    testRegression();
    testValid();
}
