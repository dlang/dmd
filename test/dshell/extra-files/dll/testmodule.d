module run.unicode_06_哪里;

int 哪里(int ö){
        return ö+2;
}

version(Windows) {
    static assert(() {
        foreach(char c; 哪里.mangleof) {
            if (c == '哪' || c == '里')
                return false;
        }

        return true;
    }(), "Function mangling on Windows must not contain Unicode characters. Got: " ~ 哪里.mangleof);
}
