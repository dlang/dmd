module line;

static assert(__LINE__ == 3);

int #line 10
x;

static assert(__LINE__ == 12);
version(Windows)
    static assert(__FILE__ == "compilable\\line.d");
else
    static assert(__FILE__ == "compilable/line.d");

#line 100 "newfile.d"

static assert(__LINE__ == 101);
static assert(__FILE__ == "newfile.d");

# line 200

static assert(__LINE__ == 201);
static assert(__FILE__ == "newfile.d");


