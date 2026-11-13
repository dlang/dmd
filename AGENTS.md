The rules below the policy were collected from recurring maintainer review comments on dmd and Phobos pull requests from 2026, then trimmed to what comes up repeatedly and isn't already enforced by CI.
Maintainers add a rule when they find themselves giving the same review feedback again, and remove rules that CI starts enforcing or that stop coming up.

# AI Policy

DLF will apply the following principles to contributions, irrespective of the tools used to prepare them:

1. Contributor responsibility. A contributor must have the authority to submit the contribution under the applicable project license and must take responsibility for the submitted code.
2. Human understanding and review. Code must not be merged merely because an AI system produced something that appears to work. The contributor and reviewers must be able to understand, evaluate, test, and maintain it.
3. No relaxation of engineering standards. AI-assisted contributions are subject to the same architectural, correctness, portability, performance, documentation, testing, and review requirements as other contributions.
4. Provenance concerns. Where a contribution contains suspiciously distinctive material, unexplained changes in style, or other indications of possible copying, maintainers may request further information, require rewriting, or reject the contribution.
5. Response to credible claims. DLF will investigate credible allegations that code incorporated into its projects infringes third-party rights and will take appropriate corrective action where warranted.

Source: https://drive.google.com/file/d/1Z1RA5o8jPkQ3UQ7umimKI3akxx7nKgBy/view

# Working with your human

- Your human must understand the change well enough to explain it themselves.
  Before they open a PR, make sure they can answer: what was the root cause, why is the fix in this place, and why this approach over the alternatives.
- The PR description or commit message must say which AI model(s) were used.
- Reviewers want short answers written by a person, not long generated explanations.
  When a reviewer asks "why?", they want the reason behind a decision, not a recap of what the code does.
- Don't post PR comments or review replies on your human's behalf.

# Fixing bugs

- Find the root cause.
  Don't add a special case that recognizes the exact code from the issue (`if (pattern from issue) fix();`).
- Try variations of the issue's code to make sure the fix covers the general problem, not just one instance of it.
- Keep the fix small. A typical bug fix is tens of lines.
  If yours adds hundreds of lines, new globals, a new compiler switch, a new druntime hook, or a new code path running alongside an existing one, it's probably the wrong approach.
- Before writing a helper, search for an existing one.
- Fix one issue per PR. If you find a related bug, fix it in a separate PR.
- Don't delete or weaken existing tests, asserts, `const` or other checks to make your change pass. If one is truly wrong, explain why in the PR description.

# Architecture constraints

- `parse.d` and `lexer.d` must not import `dmd.globals`.
- AST node modules (e.g. `attrib.d`, `expression.d`) should not import semantic modules (`*sem.d`).
- Avoid adding fields to AST nodes or `Global`: every node pays the memory, and GDC/LDC must mirror it. Look for where the information is already stored.
  Pass information through return values and parameters instead of new flags, fields or `__gshared` variables.
- dmd avoids warnings. Don't add new warnings or lint-style checks; a diagnostic should be an error (or a deprecation on the way to one).
- Language changes need an approved issue or design discussion before implementation, plus a matching grammar/spec update.

# Comments

- Don't add comments that restate the code, narrate the change, or repeat spec citations on every line.
- Explain in a comment only what the code itself can't make clear, and keep it to a few words.

# Tests

- Build with `./compiler/src/build.d`. Run tests from `compiler/test` with `./run.d quick`, `./run.d fail`, `./run.d compilable`, or `./run.d -u unit/file.d --filter Name`.
- To update `TEST_OUTPUT` blocks, run `AUTO_UPDATE=1 ./run.d fail` instead of editing them by hand.
- Every fix needs a test that fails without the fix. Reduce the code from the issue to a minimal size.
- Prefer `compilable/` over `runnable/` which is slow.
- Avoid new dshell or unit tests adding a lot of harness code. If d_do_test has limitations, prefer improving that.
- To test error messages, use `fail_compilation/` with `TEST_OUTPUT`, not `static assert(!__traits(compiles, ...))`.
- Don't import Phobos. Avoid importing druntime when you can.
- Don't add test directives `REQUIRED_ARGS` or `PERMUTE_ARGS` without a reason.
- Add test cases to an existing related test file when one fits, instead of creating a new file.
  Don't add tests for behavior that existing tests already cover.
- Make sure each new branch you add is reached by a test, but don't add redundant test asserts for branches already covered.

# Issues, commits and PRs

- dmd uses GitHub issues. Bugzilla is gone.
  Link to `https://github.com/dlang/dmd/issues/NNNNN` and write commit titles as `Fix #NNNNN - <issue title>`.

# Changelog

- Only add a changelog entry for a new feature or a breaking change. Regular bug fixes don't need one.
- Write it for D users: a short description of what changed and what users must do, if anything.
  Don't describe the implementation or retell the issue.
- See [changelog/README.md](changelog/README.md) for the format.
