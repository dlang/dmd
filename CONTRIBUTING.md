# Contributing to DMD, the D programming language reference compiler

First off, thanks for your interest in contributing!

## Reporting bugs

We exclusively use [bugzilla](https://issues.dlang.org/) for issue tracking, which is why Github issues are disabled on this repository.
Before reporting a bug, please [check bugzilla](https://issues.dlang.org/query.cgi) to see if it's already reported.
If it isn't, [create a new issue](https://issues.dlang.org/enter_bug.cgi).

For questions about a specific behavior, the [D.Learn](http://forum.dlang.org/group/learn) group is a good place to ask for clarification before reporting an issue.

### Content

When creating a new issue, include:
- the version of DMD being used (which can be found by running `dmd` with no argument).
- A test case:
  - Make it a [short, self-contained, and compilable example](http://sscce.org/).
  - Avoid dependencies on foreign code (e.g. dub packages).
  - Avoid any imports from phobos / druntime if possible.
Minimize the test case using the [DustMite tool](https://github.com/CyberShadow/DustMite/wiki).
DustMite is also available from our [tools](https://github.com/dlang/tools) repository and is distributed with DMD.

### Regressions

When finding a [regression](https://en.wikipedia.org/wiki/Software_regression), please label the issue as such:
- Set the field 'Severity' to 'Regression' (highest level of priority)
- Prefix the issue title with `[REG 2.XXX.Y]` where `2.XXX.Y` is the first broken version whenever possible.

To help track down the point where regressions were introduced, use the excellent [Digger](https://github.com/CyberShadow/digger) tool.
Digger will automatically bisect the history and identify the Pull Request that introduced the problem.

### Changelog

We use Bugzilla to list fixed issues on a new release.  This list is then included in the changelog.
For this list to be accurate then invalid or duplicated bugs must be closed with the appropriate resolution ('RESOLVED INVALID' and 'RESOLVED DUPLICATE', respectively - as opposed to e.g. 'RESOLVED FIXED').

Changes that don't come with a bugzilla entry, such as new features, or enhancement on existing features, should come with their own changelog entry. Changelog entries should be written for everyday users, not compiler contributors.
Additionally, for larger changes, you may want to add a specialized, detailed entry even if a bugzilla entry exists.
See [changelog/README.md](changelog/README.md) for details on how to add a changelog entry.
Note that after a version has entered the release window (there is a beta / the change is in stable), changes should be made directly [in the dlang.org repository](https://github.com/dlang/dlang.org/tree/master/changelog).

## Solving bugs / Submitting pull requests

Before submitting a PR, check the following to make the pulling process run smoothly are:

- Make sure to target the right branch. Regressions go to stable, and everything else to master, as outlined in [our release process](http://wiki.dlang.org/DIP75).

- When fixing a Bugzilla issue, use the title: 'Fix issue XXXXX - Issue title'.  This is recognized by both Bugzilla and our GitHub bot (dlang-bot),
  and will automatically link the issue and the pull request together (by providing a link to the issue in Github, and automatically closing bugs when pull requests are merged).

- Document the 'why' (the change is necessary and was done this way) rather than the 'how'.

- Ensure newly introduced symbols are documented and that updates to existing symbols are reflected in the documentation.

- Add a link to the PR to the Bugzilla entry (if the dlang-bot failed to do it).

- Confine a PR to addressing one Bugzilla entry, unless multiple entries are different aspects of the same bug.

- If submitting a bug fix PR that does not have a Bugzilla entry, add a Bugzilla entry for it and then submit the PR
that fixes it.

- If the pull request affects the language specifications in any way (i.e. changing the grammar, deprecating a feature, or adding a new one),
  a pull request to [the website](https://github.com/dlang/dlang.org) should be submitted in parallel.

- Follow the usual git good practice:
  - [Provide descriptive commit messages](https://chris.beams.io/posts/git-commit/)
  - Avoid changes not relevant to the issue (i.e. style issues)
  - Separate commit for separate concerns
  - Keep pull requests focused on one single topic or bug.  For example, if the fix requires a refactoring, then submit the refactoring as a separate pull request.

### Find bugs to work on

For first-time contributors, look for issues categorized as [trivial](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=trivial&product=D).
Continue with issues categorized [bootcamp](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=bootcamp&product=D).

For a hassle-free contribution look for issues categorized as [preapproved](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=preapproved&product=D).

## Refactoring

The purpose of refactoring is to make the code easier to understand and extend. It is not to change the behavior of the
program, add enhancements, or fix bugs.

- Refactorings must come with a rationale as to why it makes the code better.

- Large refactorings should be done in incremental steps that are easy to review.

- When a refactoring is broken down into multiple PRs, it is acceptable to provide a rationale in the first PR and link to it in subsequent PR.

- Pull requests that do non-trivial refactorings should not include other changes, such as new feature or bug fix.
   While submitting multiple dependent pull requests can be done to help the reviewers judge of the need for a refactoring, any refactoring will be assessed on its own merit.


## DMD Best Practices

Here is a shortlist of stylistic issues the core team will expect in
pull requests. Much of the source code does not follow these, but
we expect new code to, and PRs retrofitting the existing code to
follow it is welcome.

1. Use attributes `const`/`nothrow`/`pure`/`scope`/`@safe`/`private`/etc.
Successfully using `pure` functions is regarded with particular favor.

2. Use correct Ddoc function comment blocks. Do not use Ddoc comments for
overrides unless the overriding function does something different (as far as
the caller is concerned) than the overridden function. Ddoc comment blocks
are often overkill for nested functions and function literals; use ordinary
comments for those. Follow the [D Style](https://dlang.org/dstyle.html#phobos_documentation)
for comment blocks.

3. Do not use `strlen`/`strcmp` and their ilk. Use D arrays instead.
If slicing from a `char*` is required then use `dmd.utils.toDString`
or the member function `.toString` that is implemented in many classes.

4. Use `ref`/`out` instead of raw pointers.

5. Use nested functions to get rid of rats' nests of goto's.

6. Look for duplicative code and factor out into functions.

7. Declare local variables as `const` as much as possible.

8. Use Single Assignment for local variables:
```
T t = x;
...
t = y;
...
```
becomes:
```
T tx = x;
...
T ty = y;
...
```

9. "Shrinkwrap" the scope of local variables as tightly as possible
around their uses.

10. Similar to (8), use distinct variable names for non-overlapping uses.

11. Avoid the use of mutable globals as much as practical. Consider passing them
in as parameters.

12. Avoid the use of default parameters. Spell them out.

13. Minimize the use of overloading.

14. Avoid clever code. Anybody can write clever code. It takes a genius to write
simple code.

15. Try to reduce cyclomatic complexity, i.e. think about how to make the code work
without control flow statements.

16. Try not to mix functions that "answer a question" with functions that
"mutate the data".
This was done successfully in src/dmd/escape.d, it wasn't easy, but
it was well worth it.

17. Try to eliminate reliance on `global.errors`.

18. For aggregates that expose public access to fields, think hard about why this is
necessary and if it can be done better. Merely replacing them with read/write properties
accomplishes nothing. The more of its internal details can be made private, the better.

19. Try to use function prefixes:

* `is` is the parameter in a certain category?
* `has` does the parameter have a certain feature?
* `can` for can I do X with the parameter?

Such functions should not be mutating the data nor issuing error messages.

20. The function return value variable should be named `result`.

21. The more constrained the scope of a name is, the shorter it should be.

22. Public declarations in modules should be "above the fold", i.e. first in the file, thus making the API of the module
easily visible when opening the file. Private declarations should follow afterwards.

## The following will not be viewed with favor:

1. Shuffling all the code about

2. As a general rule, any improvement that is implemented by using sed scripts
across the source tree is likely to be disruptive and unlikely to provide
significant improvement.

3. Reformatting into your personal style. Please stick with the existing style.
Use the [D Style](https://dlang.org/dstyle.html#phobos_documentation) for new code.

As always, treating the above as a sacred writ is a huge mistake. Use
your best judgment on a case-by-case basis. Blindly doing things just
adds more technical debt.


## dmd-internals mailing list

For questions and discussions related to DMD development, a [mailing list](https://forum.dlang.org/group/dmd) is available.
