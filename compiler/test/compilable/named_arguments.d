
string fun(string x, string y, string z = "Z", string w = "W")
{
	return x ~ y ~ z ~ w;
}

static assert(fun(   "x",    "y") == "xyZW");
static assert(fun(   "x",    "y", "z", "w") == "xyzw");
static assert(fun(x: "x", y: "y", z: "z", w: "w") == "xyzw");
static assert(fun(w: "w", z: "z", y: "y", x: "x") == "xyzw");
static assert(fun(y: "y",    "z", x: "x") == "xyzW");
static assert(fun(   "x",    "y", w: "w") == "xyZw");

// UFCS
static assert("x".fun("y", w: "w") == "xyZw");
