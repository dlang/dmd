/*
TEST_OUTPUT:
---
On: globala
On: globalb
On: globalc
On: freefunctiona
On: freefunctionb
On: sfield1a
On: method1a
On: Ca
On: sfield1b
On: method1b
On: Cb
On: sfield2a
On: method2a
On: Sa
On: sfield2b
On: method2b
On: Sb
On: method3a
On: Ia
On: method3b
On: Ib
On: C_Parent
Child: C_Child
On: E
On: I_Parent
Child: I_Child
Child: C_I_Child
Child: C_I2_Child
---
*/

string[] caught1, caught2;

struct UDA {
    void opUDAOn(alias symbol)() {
        pragma(msg, "On: ", __traits(identifier, symbol));
    }

    void opChildOfUDAOn(alias symbol)() {
        pragma(msg, "Child: ", __traits(identifier, symbol));
    }
}

@UDA
int globala;

@UDA()
int globalb;

@UDA
@UDA()
int globalc;

@UDA
void freefunctiona() {
}

@UDA()
void freefunctionb() {
}

@UDA
class Ca {
    @UDA
    int field1a;

    @UDA
    static int sfield1a;

    @UDA
    void method1a() {
    }
}

@UDA()
class Cb {
    @UDA()
    int field1b;

    @UDA()
    static int sfield1b;

    @UDA()
    void method1b() {
    }
}

@UDA
struct Sa {
    @UDA
    int field2a;

    @UDA
    static int sfield2a;

    @UDA
    void method2a() {
    }
}

@UDA()
struct Sb {
    @UDA()
    int field2b;

    @UDA()
    static int sfield2b;

    @UDA()
    void method2b() {
    }
}

@UDA
interface Ia {
    @UDA
    void method3a();
}

@UDA()
interface Ib {
    @UDA()
    void method3b();
}

@UDA
class C_Parent {
}

class C_Child : C_Parent {
}

@UDA
enum E {
    A
}

@UDA
interface I_Parent {
}

interface I_Child : I_Parent {
}

class C_I_Child : I_Parent {
}

class C_I2_Child : I_Child {
}
