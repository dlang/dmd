/*
REQUIRED_ARGS: -requireinit
*/

class TestClass
{
    // Test class fields
    TestClass tc = null;
    TestStruct ts = TestStruct();
    string s = "";
    int i = 0;
    int[] a = [1,2,3];

    // Test class fields with void initializations
    TestClass tc2 = void;
    TestStruct ts2 = void;
    string s2= void;
    int i2 = void;
    int[] a2 = void;
}
struct TestStruct
{
    // Test struct filds
    TestClass tc = null;
    TestStruct ts = TestStruct();
    string s = "";
    int i = 0;
    int[] a = [1,2,3];

    // Test struct fields with void initializations
    TestClass tc2 = void;
    TestStruct ts2 = void;
    string s2= void;
    int i2 = void;
    int[] a2 = void;
}

// Test global declarations
TestClass tc = null;
TestStruct ts = TestStruct();
string s = "";
int i = 0;
int[] a = [1,2,3];

// Test global void initializations
TestClass tc2 = void;
TestStruct ts2 = void;
string s2= void;
int i2 = void;
int[] a2 = void;

void main()
{
    // Test local declarations
    TestClass ltc = null;
    TestStruct lts = TestStruct();
    string ls = "";
    int li = 0;
    int[] la = [1,2,3];

    // Test local void initializations
    TestClass tc2 = void;
    TestStruct ts2 = void;
    string s2= void;
    int i2 = void;
    int[] a2 = void;
}
