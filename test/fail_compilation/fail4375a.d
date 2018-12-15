// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else

void main() {
	if (true)
		if (false)
			assert(3);
    else
        assert(4);
}

