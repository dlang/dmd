enum file = __FILE__;

#line 1 "a"
static assert(__LINE__ == 1);
static assert(__FILE__ == "a");

#line 3
#line 10 "b"
static assert(__LINE__ == 10);
static assert(__FILE__ == "b");

#line 17
static assert(__LINE__ == 17);
static assert(__FILE__ == "b");

#line
static assert(__LINE__ == 24);
static assert(__FILE__ == file);

#line
static assert(__LINE__ == 28);
static assert(__FILE__ == file);

#line 42
static assert(__LINE__ == 42);
static assert(__FILE__ == file);

#line
static assert(__LINE__ == 36);
static assert(__FILE__ == file);

void main() { }
