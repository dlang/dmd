// https://github.com/dlang/dmd/issues/20502
struct mg_str {

};

void mg_str_s() {

}

#define mg_str(s) mg_str_s(s)
