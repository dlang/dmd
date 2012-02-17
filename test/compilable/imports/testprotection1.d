module same_package.imp;

string decls(string prot)
{
    return
(prot == "none" ? "" : prot ~ ":")~`
    int            `~prot~`_variable;
    class          `~prot~`_class {}
    struct         `~prot~`_struct {}
    union          `~prot~`_union {}
    enum           `~prot~`_enum_1 { A }
    enum           `~prot~`_enum_2 = 2;
    alias int      `~prot~`_type_alias;
    template       `~prot~`_template() {}
    template       `~prot~`_eponymous_template() { enum `~prot~`_eponymous_template = 0; }
    mixin template `~prot~`_mixin_template() {}
    void           `~prot~`_func() {}
    static void    `~prot~`_static_func() {}
`;
}

mixin template protection_body()
{
    mixin(decls("none"));
    mixin(decls("public"));
    mixin(decls("package"));
    mixin(decls("private"));
}

public:

mixin protection_body!();

struct   public_struct     { mixin protection_body!(); }
class    public_class      { mixin protection_body!(); }
template public_template() { mixin protection_body!(); }

package:

struct   package_struct     { mixin protection_body!(); }
class    package_class      { mixin protection_body!(); }
template package_template() { mixin protection_body!(); }

private:

struct   private_struct     { mixin protection_body!(); }
class    private_class      { mixin protection_body!(); }
template private_template() { mixin protection_body!(); }

public:

enum HasPackageAccess : bool
{
    yes = true,
    no  = false,
};


mixin template basic_test_cases(HasPackageAccess pkg)
{
    static assert(__traits(compiles, () {public_struct s;}));
    static assert(__traits(compiles, () {auto c = new public_class;}));
    static assert(__traits(compiles, public_template!()));
    static assert(__traits(compiles, public_eponymous_template!()));

    static assert(pkg == __traits(compiles, () {package_struct s;}));
    static assert(pkg == __traits(compiles, () {auto c = new package_class;}));
    static assert(pkg == __traits(compiles, package_template!()));
    static assert(pkg == __traits(compiles, package_eponymous_template!()));

    static assert(!__traits(compiles, () {private_struct s;}));
    static assert(!__traits(compiles, () {auto c = new private_class;}));
    static assert(!__traits(compiles, private_template!()));
    static assert(!__traits(compiles, private_eponymous_template!()));
}


mixin template builtin_property_test_cases(HasPackageAccess pkg)
{
    static assert(__traits(compiles, public_struct.stringof));
    static assert(__traits(compiles, public_class.stringof));
    static assert(__traits(compiles, public_func.mangleof));

    static assert(pkg == __traits(compiles, package_struct.stringof));
    static assert(pkg == __traits(compiles, package_class.stringof));
    static assert(pkg == __traits(compiles, package_func.mangleof));

    static assert(!__traits(compiles, private_struct.stringof));
    static assert(!__traits(compiles, private_class.stringof));
    static assert(!__traits(compiles, private_func.mangleof));
}


template TypeTuple(T...)
{
    alias T TypeTuple;
}

// Need to split those (Bug #7406)
public alias TypeTuple!(
    public_struct,
    public_class,
    package_struct,
    package_class,
    private_struct,
    private_class,
) ScopeSymbolsTypes;

public alias TypeTuple!(
    same_package.imp,
    public_template!(),
    package_template!(),
    private_template!(),
) ScopeSymbolsExpressions;

/* Nested scopes are public by default even for private symbols,
 * i.e. one can't instantiate a private struct, but access all it's members.
 */
mixin template scope_test_cases(HasPackageAccess pkg)
{
    static assert(__traits(compiles, none_variable), none_variable);
    static assert(__traits(compiles, none_class));
    static assert(__traits(compiles, none_struct));
    static assert(__traits(compiles, none_union));
    static assert(__traits(compiles, none_enum_1));
    static assert(__traits(compiles, none_enum_2));
    static assert(__traits(compiles, none_type_alias));
    static assert(__traits(compiles, none_template!()));
    static assert(__traits(compiles, none_eponymous_template!()));
    static assert(__traits(compiles, () { mixin none_mixin_template!(); }));
    static assert(__traits(compiles, none_func));
    static assert(__traits(compiles, none_static_func));

    static assert(__traits(compiles, public_variable));
    static assert(__traits(compiles, public_class));
    static assert(__traits(compiles, public_struct));
    static assert(__traits(compiles, public_union));
    static assert(__traits(compiles, public_enum_1));
    static assert(__traits(compiles, public_enum_2));
    static assert(__traits(compiles, public_type_alias));
    static assert(__traits(compiles, public_template!()));
    static assert(__traits(compiles, public_eponymous_template!()));
    static assert(__traits(compiles, () { mixin public_mixin_template!(); }));
    static assert(__traits(compiles, public_func));
    static assert(__traits(compiles, public_static_func));

    static assert(pkg == __traits(compiles, package_variable));
    static assert(pkg == __traits(compiles, package_class));
    static assert(pkg == __traits(compiles, package_struct));
    static assert(pkg == __traits(compiles, package_union));
    static assert(pkg == __traits(compiles, package_enum_1));
    static assert(pkg == __traits(compiles, package_enum_2));
    static assert(pkg == __traits(compiles, package_type_alias));
    static assert(pkg == __traits(compiles, package_template!()));
    static assert(pkg == __traits(compiles, package_eponymous_template!()));
    static assert(pkg == __traits(compiles, () { mixin package_mixin_template!(); }));
    static assert(pkg == __traits(compiles, package_func));
    static assert(pkg == __traits(compiles, package_static_func));

    static assert(!__traits(compiles, private_variable));
    static assert(!__traits(compiles, private_class));
    static assert(!__traits(compiles, private_struct));
    static assert(!__traits(compiles, private_union));
    static assert(!__traits(compiles, private_enum_1));
    static assert(!__traits(compiles, private_enum_2));
    static assert(!__traits(compiles, private_type_alias));
    static assert(!__traits(compiles, private_template!()));
    static assert(!__traits(compiles, private_eponymous_template!()));
    static assert(!__traits(compiles, () { mixin private_mixin_template!(); }));
    static assert(!__traits(compiles, private_func));
    static assert(!__traits(compiles, private_static_func));
}


template template_test_typ(T)
{
    enum template_test_typ = T.stringof;
}

template template_test_sym(alias S)
{
    enum template_test_sym = S.stringof;
}

template template_test_tup(T...)
{
    static if (T.length > 0)
        enum template_test_tup = T[0].stringof ~ template_test_tup!(T[1 .. $]);
    else
        enum template_test_tup = "";
}

/* Templates have full access to their arguments. Protection checks
 * are only done at instantiation scope. This doesn't work yet for
 * aliases to private functions (Bugzilla 4533).
 */
version = Bug4533;
mixin template template_test_cases()
{
    mixin protection_body!();

    static assert(__traits(compiles, template_test_sym!(none_variable)));
    static assert(__traits(compiles, template_test_typ!(none_class)));
    static assert(__traits(compiles, template_test_typ!(none_struct)));
    static assert(__traits(compiles, template_test_typ!(none_union)));
    static assert(__traits(compiles, template_test_typ!(none_enum_1)));
    static assert(__traits(compiles, template_test_sym!(none_enum_2)));
    static assert(__traits(compiles, template_test_typ!(none_type_alias)));
    static assert(__traits(compiles, template_test_sym!(none_template!())));
    static assert(__traits(compiles, template_test_sym!(none_eponymous_template!())));
    static assert(__traits(compiles, template_test_sym!(none_mixin_template)));
    static assert(__traits(compiles, template_test_sym!(none_func)));
    static assert(__traits(compiles, template_test_sym!(none_static_func)));
    static assert(__traits(compiles, template_test_tup!(
                               none_variable, none_class, none_enum_1, none_mixin_template)));

    static assert(__traits(compiles, template_test_sym!(public_variable)));
    static assert(__traits(compiles, template_test_typ!(public_class)));
    static assert(__traits(compiles, template_test_typ!(public_struct)));
    static assert(__traits(compiles, template_test_typ!(public_union)));
    static assert(__traits(compiles, template_test_typ!(public_enum_1)));
    static assert(__traits(compiles, template_test_sym!(public_enum_2)));
    static assert(__traits(compiles, template_test_typ!(public_type_alias)));
    static assert(__traits(compiles, template_test_sym!(public_template!())));
    static assert(__traits(compiles, template_test_sym!(public_eponymous_template!())));
    static assert(__traits(compiles, template_test_sym!(public_mixin_template)));
    static assert(__traits(compiles, template_test_sym!(public_func)));
    static assert(__traits(compiles, template_test_sym!(public_static_func)));
    static assert(__traits(compiles, template_test_tup!(
                               public_variable, public_class, public_enum_1, public_mixin_template)));

    static assert(__traits(compiles, template_test_sym!(package_variable)));
    static assert(__traits(compiles, template_test_typ!(package_class)));
    static assert(__traits(compiles, template_test_typ!(package_struct)));
    static assert(__traits(compiles, template_test_typ!(package_union)));
    static assert(__traits(compiles, template_test_typ!(package_enum_1)));
    static assert(__traits(compiles, template_test_sym!(package_enum_2)));
    static assert(__traits(compiles, template_test_typ!(package_type_alias)));
    static assert(__traits(compiles, template_test_sym!(package_template!())));
    static assert(__traits(compiles, template_test_sym!(package_eponymous_template!())));
    static assert(__traits(compiles, template_test_sym!(package_mixin_template)));
    version (Bug4533) {} else
    {
        static assert(__traits(compiles, template_test_sym!(package_func)));
        static assert(__traits(compiles, template_test_sym!(package_static_func)));
    }
    static assert(__traits(compiles, template_test_tup!(
                               package_variable, package_class, package_enum_1, package_mixin_template)));

    static assert(__traits(compiles, template_test_sym!(private_variable)));
    static assert(__traits(compiles, template_test_typ!(private_class)));
    static assert(__traits(compiles, template_test_typ!(private_struct)));
    static assert(__traits(compiles, template_test_typ!(private_union)));
    static assert(__traits(compiles, template_test_typ!(private_enum_1)));
    static assert(__traits(compiles, template_test_sym!(private_enum_2)));
    static assert(__traits(compiles, template_test_typ!(private_type_alias)));
    static assert(__traits(compiles, template_test_sym!(private_template!())));
    static assert(__traits(compiles, template_test_sym!(private_eponymous_template!())));
    static assert(__traits(compiles, template_test_sym!(private_mixin_template)));
    version (Bug4533) {} else
    {
        static assert(__traits(compiles, template_test_sym!(private_func)));
        static assert(__traits(compiles, template_test_sym!(private_static_func)));
    }
    static assert(__traits(compiles, template_test_tup!(
                               private_variable, private_class, private_enum_1, private_mixin_template)));
}
