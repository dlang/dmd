// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

module imports.testprot5770;

import imports.prot5770;

version(all)    // access module members from module scope
{
    static assert( is(typeof(C.init.   publicF())));
    static assert(!is(typeof(C.init.protectedF())));
    static assert( is(typeof(C.init.  packageF())));
    static assert(!is(typeof(C.init.  privateF())));

    static assert( is(typeof(C.init.   publicTF())));
  //static assert(!is(typeof(C.init.protectedTF())));   // Bugzilla 5770
    static assert( is(typeof(C.init.  packageTF())));
  //static assert(!is(typeof(C.init.  privateTF())));   // Bugzilla 5770
}
version(all)    // access class members from module scope
{
    static assert( is(typeof(C.init.   publicF())));
    static assert(!is(typeof(C.init.protectedF())));
    static assert( is(typeof(C.init.  packageF())));
    static assert(!is(typeof(C.init.  privateF())));

    static assert( is(typeof(C.init.   publicTF())));
  //static assert(!is(typeof(C.init.protectedTF())));   // Bugzilla 5770
    static assert( is(typeof(C.init.  packageTF())));
  //static assert(!is(typeof(C.init.  privateTF())));   // Bugzilla 5770

    static assert( is(typeof(D.init.   publicF())));
    static assert(!is(typeof(D.init.protectedF())));
    static assert( is(typeof(D.init.  packageF())));
    static assert(!is(typeof(D.init.  privateF())));

    static assert( is(typeof(D.init.   publicTF())));
  //static assert(!is(typeof(D.init.protectedTF())));   // Bugzilla 5770
    static assert( is(typeof(D.init.  packageTF())));
  //static assert(!is(typeof(D.init.  privateTF())));   // Bugzilla 5770
}
version(all)    // access struct members from module scope
{
    static assert( is(typeof(S.init.   publicF())));
    static assert(!is(typeof(S.init.protectedF())));
    static assert( is(typeof(S.init.  packageF())));
    static assert(!is(typeof(S.init.  privateF())));

    static assert( is(typeof(S.init.   publicTF())));
  //static assert(!is(typeof(S.init.protectedTF())));   // Bugzilla 5770
    static assert( is(typeof(S.init.  packageTF())));
  //static assert(!is(typeof(S.init.  privateTF())));   // Bugzilla 5770
}

void testC1()
{
    C c = new C();

    static assert( is(typeof(c.   publicF())));
    static assert(!is(typeof(c.protectedF())));
    static assert( is(typeof(c.  packageF())));
    static assert(!is(typeof(c.  privateF())));

    static assert( is(typeof(c.   publicTF())));
  //static assert(!is(typeof(c.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(c.  packageTF())));
  //static assert(!is(typeof(c.  privateTF())));    // Bugzilla 5770

    D d = new D();

    static assert( is(typeof(d.   publicF())));
  //static assert(!is(typeof(d.protectedF())));     // Bugzilla 5770
    static assert( is(typeof(d.  packageF())));
    static assert(!is(typeof(d.  privateF())));

    static assert( is(typeof(d.   publicTF())));
  //static assert(!is(typeof(d.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(d.  packageTF())));
  //static assert(!is(typeof(d.  privateTF())));    // Bugzilla 5770
}
void testC2()()
{
    C c = new C();

    static assert( is(typeof(c.   publicF())));
    static assert(!is(typeof(c.protectedF())));
    static assert( is(typeof(c.  packageF())));
    static assert(!is(typeof(c.  privateF())));

    static assert( is(typeof(c.   publicTF())));
  //static assert(!is(typeof(c.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(c.  packageTF())));
  //static assert(!is(typeof(c.  privateTF())));    // Bugzilla 5770

    D d = new D();

    static assert( is(typeof(d.   publicF())));
  //static assert(!is(typeof(d.protectedF())));     // Bugzilla 5770
    static assert( is(typeof(d.  packageF())));
    static assert(!is(typeof(d.  privateF())));

    static assert( is(typeof(d.   publicTF())));
  //static assert(!is(typeof(d.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(d.  packageTF())));
  //static assert(!is(typeof(d.  privateTF())));    // Bugzilla 5770
}
alias testC2x = testC2!();

void testS1()
{
    S s;

    static assert( is(typeof(s.   publicF())));
    static assert(!is(typeof(s.protectedF())));
    static assert( is(typeof(s.  packageF())));
    static assert(!is(typeof(s.  privateF())));

    static assert( is(typeof(s.   publicTF())));
  //static assert(!is(typeof(s.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(s.  packageTF())));
  //static assert(!is(typeof(s.  privateTF())));    // Bugzilla 5770
}
void testS2()()
{
    S s;

    static assert( is(typeof(s.   publicF())));
    static assert(!is(typeof(s.protectedF())));
    static assert( is(typeof(s.  packageF())));
    static assert(!is(typeof(s.  privateF())));

    static assert( is(typeof(s.   publicTF())));
  //static assert(!is(typeof(s.protectedTF())));    // Bugzilla 5770
    static assert( is(typeof(s.  packageTF())));
  //static assert(!is(typeof(s.  privateTF())));    // Bugzilla 5770
}
alias testS2x = testS2!();

class D : C
{
    void test1()
    {
        static assert( is(typeof(this.   publicF())));
        static assert( is(typeof(this.protectedF())));
        static assert( is(typeof(this.  packageF())));
        static assert(!is(typeof(this.  privateF())));

        static assert( is(typeof(this.   publicTF())));
        static assert( is(typeof(this.protectedTF())));
        static assert( is(typeof(this.  packageTF())));
      //static assert(!is(typeof(this.  privateTF())));     // Bugzilla 5770

        static assert( is(typeof(super.   publicF())));
        static assert( is(typeof(super.protectedF())));
        static assert( is(typeof(super.  packageF())));
        static assert(!is(typeof(super.  privateF())));

        static assert( is(typeof(super.   publicTF())));
        static assert( is(typeof(super.protectedTF())));
        static assert( is(typeof(super.  packageTF())));
      //static assert(!is(typeof(super.  privateTF())));    // Bugzilla 5770

        auto dg = {
            static assert( is(typeof(this.   publicF())));
            static assert( is(typeof(this.protectedF())));
            static assert( is(typeof(this.  packageF())));
            static assert(!is(typeof(this.  privateF())));

            static assert( is(typeof(this.   publicTF())));
            static assert( is(typeof(this.protectedTF())));
            static assert( is(typeof(this.  packageTF())));
          //static assert(!is(typeof(this.  privateTF())));     // Bugzilla 5770

            static assert( is(typeof(super.   publicF())));
          //static assert( is(typeof(super.protectedF())));     // Bugzilla 5770
            static assert( is(typeof(super.  packageF())));
            static assert(!is(typeof(super.  privateF())));

            static assert( is(typeof(super.   publicTF())));
            static assert( is(typeof(super.protectedTF())));
            static assert( is(typeof(super.  packageTF())));
          //static assert(!is(typeof(super.  privateTF())));    // Bugzilla 5770
        };
    }
    void test2()()
    {
        static assert( is(typeof(this.   publicF())));
        static assert( is(typeof(this.protectedF())));
        static assert( is(typeof(this.  packageF())));
        static assert(!is(typeof(this.  privateF())));

        static assert( is(typeof(this.   publicTF())));
        static assert( is(typeof(this.protectedTF())));
        static assert( is(typeof(this.  packageTF())));
      //static assert(!is(typeof(this.  privateTF())));     // Bugzilla 5770

        static assert( is(typeof(super.   publicF())));
      //static assert( is(typeof(super.protectedF())));     // Bugzilla 5770
        static assert( is(typeof(super.  packageF())));
        static assert(!is(typeof(super.  privateF())));

        static assert( is(typeof(super.   publicTF())));
        static assert( is(typeof(super.protectedTF())));
        static assert( is(typeof(super.  packageTF())));
      //static assert(!is(typeof(super.  privateTF())));    // Bugzilla 5770

        auto dg = {
            static assert( is(typeof(this.   publicF())));
            static assert( is(typeof(this.protectedF())));
            static assert( is(typeof(this.  packageF())));
            static assert(!is(typeof(this.  privateF())));

            static assert( is(typeof(this.   publicTF())));
            static assert( is(typeof(this.protectedTF())));
            static assert( is(typeof(this.  packageTF())));
          //static assert(!is(typeof(this.  privateTF())));     // Bugzilla 5770

            static assert( is(typeof(super.   publicF())));
          //static assert( is(typeof(super.protectedF())));     // Bugzilla 5770
            static assert( is(typeof(super.  packageF())));
            static assert(!is(typeof(super.  privateF())));

            static assert( is(typeof(super.   publicTF())));
            static assert( is(typeof(super.protectedTF())));
            static assert( is(typeof(super.  packageTF())));
          //static assert(!is(typeof(super.  privateTF())));    // Bugzilla 5770
        };
    }
    alias test2x = test2!();    // instantiate
}
