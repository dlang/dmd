// https://github.com/dlang/dmd/issues/21244
int z = _Generic(1, int()(int): 3, int: 3);
