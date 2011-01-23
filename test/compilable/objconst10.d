
class C {
    
    const(C) constTest() const { return this; }
    immutable(C) immutableTest() immutable { return this; }
    shared(C) sharedTest() shared { return this; }
    shared(const(C)) sharedConstTest() shared const { return this; }
    inout(C) inoutTest(inout(C) a) { return a; }
    
    const(C)ref constTestRef() const { return this; }
    immutable(C)ref immutableTestRef() immutable { return this; }
    shared(C)ref sharedTestRef() shared { return this; }
    shared(const(C))ref sharedConstTestRef() shared const { return this; }
    inout(C)ref inoutTestRef(inout(C)ref a) { return a; }
    
}

void main() {
    C a = new C;
    const(C)ref ac;
    ac = a.constTest();
    ac = a.constTestRef();
//    a = a.inoutTest(a);
//    a = a.inoutTestRef(a);
    
    immutable(C)ref b = new immutable(C);
    const(C)ref bc;
    bc = b.constTest();
    bc = b.constTestRef();
//    b = b.inoutTest(b);
//    b = b.inoutTestRef(b);
    b = b.immutableTest();
    b = b.immutableTestRef();
    
    shared(C)ref c = new shared(C);
    shared(const(C))ref cc;
    cc = c.sharedConstTest();
    cc = c.sharedConstTestRef();
//    c = c.inoutTest(c);
//    c = c.inoutTestRef(c);
    c = c.sharedTest();
    c = c.sharedTestRef();
}
