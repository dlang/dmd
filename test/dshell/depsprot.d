import dshell;
void main()
{
    Vars.set("deps_file", "$OUTPUT_BASE/compile.deps");
    run("$DMD -m$MODEL -deps=$deps_file -Idshell/imports -o- $EXTRA_FILES/$TEST_NAME.d");
    Vars.deps_file
        .grep("^$TEST_NAME.*${TEST_NAME}_default")
        .grep("private")
        .enforceMatches("Default import protection in dependency file should be 'private'");
    Vars.deps_file
        .grep("^$TEST_NAME.*${TEST_NAME}_public")
        .grep("public")
        .enforceMatches("Public import protection in dependency file should be 'public'");
    Vars.deps_file
        .grep("^$TEST_NAME.*${TEST_NAME}_private")
        .grep("private")
        .enforceMatches("Private import protection in dependency file should be 'private'");
}
