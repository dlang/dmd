# Tools

These files implement tools and utilities used by the test suite.

| File                                       | Purpose                                                                                         |
|--------------------------------------------|-------------------------------------------------------------------------------------------------|
| [`d_do_test.d`](d_do_test.d)               | Test runner for all non-`unit` tests                                                            |
| [`dshell_prebuilt.d`](dshell_prebuilt.d)   | Common utilities for `dshell` tests                                                             |
| [`paths.d`](paths.d)                       | Definitions for [common environment variables](../README.md#environment-variables) (e.g. `DMD`) |
| [`sanitize_json.d`](sanitize_json.d)       | Remove platform-specific information from dmd's JSON output (`-X`)                              |
| [`unit_test_runner.d`](unit_test_runner.d) | Test runner for `unit` tests                                                                    |

---

The following files are deprecated and will be removed in the future.

| File                                       | Purpose                                                                                         |
|--------------------------------------------|-------------------------------------------------------------------------------------------------|
| `sh_do_test.sh`                            | Old test runner, superseded by `d_do_test.d`                                                    |
| `postscript.sh`                            | Setup before running bash scripts defined as `POSTSCRIPT`                                       |
| `common_funcs.sh`                          | Common functions for shell scripts                                                              |

---

Refer to [test/README.md](../README.md) for more general information on the test suite.