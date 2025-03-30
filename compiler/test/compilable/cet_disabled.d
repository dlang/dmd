// Test for Intel CET protection disabled

static assert(__traits(getTargetInfo, "CET") == 0);
