
/*
 * MyDll demonstration of how to write D DLLs.
 *
 * stripped down version of mydll.d to avoid inclusion into module dependency
 * for dynamic linking
 */


/* --------------------------------------------------------- */

class MyClass
{
    string concat(string a, string b);
    void free(string s);
}

export MyClass getMyClass();
