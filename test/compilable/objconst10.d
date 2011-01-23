
class C {
    
    const(C) constTest() const { return this; }
    immutable(C) immutableTest() immutable { return this; }
    shared(C) sharedTest() shared { return this; }
    shared(const(C)) sharedConstTest() shared const { return this; }
    inout(C) inoutTest() inout { return this; }
    
    const(C)ref constTestRef() const { return this; }
    immutable(C)ref immutableTestRef() immutable { return this; }
    shared(C)ref sharedTestRef() shared { return this; }
    shared(const(C))ref sharedConstTestRef() shared const { return this; }
    inout(C)ref inoutTestRef() inout { return this; }
    
}

void main() {
    C a = new C;
    const(C) ac;
    ac = a.constTest();
    ac = a.constTestRef();
    a = a.inoutTest();
    a = a.inoutTestRef();
    
    immutable(C)ref b = new immutable(C);
    const(C)ref bc;
    bc = b.constTest();
    bc = b.constTestRef();
    b = b.inoutTest();
    b = b.inoutTestRef();
    b = b.immutableTest();
    b = b.immutableTestRef();
    
    shared(C)ref c = new shared(C);
    const(C)ref cc;
    cc = c.sharedConstTest();
    cc = c.sharedConstTestRef();
    c = c.inoutTest();
    c = c.inoutTestRef();
    c = c.sharedTest();
    c = c.sharedTestRef();
}
