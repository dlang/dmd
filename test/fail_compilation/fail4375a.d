// 4375: Dangling else

void main() {
	if (true)
		if (false)
			assert(3);
    else
        assert(4);
}

