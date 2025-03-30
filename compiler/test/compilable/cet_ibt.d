// REQUIRED_ARGS: -fIBT

// Test for Intel CET IBT (branch) protection

static assert(__traits(getTargetInfo, "CET") == 1);
