# Contributing to DMD, the D programming language reference compiler

First off, thanks for your interest in contributing !

## Reporting bugs

We exclusively use [bugzilla](https://issues.dlang.org/) for issue tracking, which is why Github issues are disabled on this repository.
If you found a bug, please [check bugzilla](https://issues.dlang.org/query.cgi) to see if it's already reported.
If it isn't, you can [create a new issue](https://issues.dlang.org/enter_bug.cgi).

If you have question about a specific behavior, the [D.Learn](http://forum.dlang.org/group/learn) group is a good place to ask for clarification before reporting an issue.

### Content

When creating a new issue, make sure to include:
- which version of DMD you are using (which can be found by running `dmd` with no argument).
- A test case:
  - Make it a [short, self contained and compilable example](http://sscce.org/).
  - Avoid dependencies to foreign code (e.g. dub packages).
  - Avoid any imports from phobos / druntime if possible.
You can try minimizing your test case using the [DustMite tool](https://github.com/CyberShadow/DustMite/wiki).
DustMite  is also available from our [tools](https://github.com/dlang/tools) repository and is distributed with DMD.

### Regressions

When finding a [regression](https://en.wikipedia.org/wiki/Software_regression), please label the issue as such:
- Set the field 'Severity' to 'Regression' (highest level of priority)
- Prefix the issue title with `[REG 2.XXX.Y]` where `2.XXX.Y` is the first broken version whenever possible.

To help track down the point where regressions were introduced down, you can use the excellent [Digger](https://github.com/CyberShadow/digger) tool.
Digger will automatically bisect the history for you.

### Changelog

We use bugzilla to list fixed issues on a new release.  This list is then included in the changelog.
For this list to be accurate then invalid or duplicated bugs must be closed with the appropriate resolution ('RESOLVED INVALID' and 'RESOLVED DUPLICATE', respectively - as opposed to e.g. 'RESOLVED FIXED').


## Solving bugs / Submitting pull requests

Before submitting a PR there are some things you can check which will hopefully make the pulling process run smoothly.

- Make sure to target the right branch.  Regressions go to stable, and everything else to master, as outlined in [our release process](http://wiki.dlang.org/DIP75).

- When fixing a bugzilla issue, use the title : 'Fix issue XXXXX - Issue title'.  This is recognized by both bugzilla and our github bot (dlang-bot),
  and will automatically link the issue and the pull request together (by providing a link to the issue in Github, and automatically closing bugs when pull requests are merged).

- Document the 'why' (the change is necessary and was done this way) rather than the 'how'.

- Ensure newly introduced symbols are documented and that updates to existing symbols are reflected in the documentation.

- Add a link to the PR to the bugzilla entry.

- If your pull request affects the language specifications in any way (i.e. changing the grammar, deprecating a feature or adding a new one),
  a pull request to [the website](https://github.com/dlang/dlang.org) should be submitted in parallel.

- Follow the usual git good practice:
  - Avoid changes not relevant to the issue (i.e. style issues)
  - Separate commit for separate concerns
  - Descriptive commit messages ease review and catching bugs
  - Keep pull requests focused on one single topic or bug.  For example, if your fix requires a refactoring, then the refactoring should be submitted as a separate pull request.

### Find bugs to work on

For first-time contributers, we suggest to look for issues categorized as [trivial](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=trivial&product=D). You may continue with issues categorized [bootcamp](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=bootcamp&product=D).

If you want a hassle-free contribution look for issues categorized as [preapproved](https://issues.dlang.org/buglist.cgi?component=dmd&keywords=preapproved&product=D).

## dmd-internals mailing list

For questions and discussions related to DMD development, a [mailing list](https://forum.dlang.org/group/dmd) is available.


## Financial contributions

We also welcome financial contributions in full transparency on our [open collective](https://opencollective.com/dlang).
Anyone can file an expense. If the expense makes sense for the development of the community, it will be "merged" in the ledger of our open collective by the core contributors and the person who filed the expense will be reimbursed.


## Credits


### Contributors

Thank you to all the people who have already contributed to dlang!
<a href="graphs/contributors"><img src="https://opencollective.com/dlang/contributors.svg?width=890" /></a>


### Backers

Thank you to all our backers! [[Become a backer](https://opencollective.com/dlang#backer)]

<a href="https://opencollective.com/dlang#backers" target="_blank"><img src="https://opencollective.com/dlang/backers.svg?width=890"></a>


### Sponsors

Thank you to all our sponsors! (please ask your company to also support this open source project by [becoming a sponsor](https://opencollective.com/dlang#sponsor))

<a href="https://opencollective.com/dlang/sponsor/0/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/1/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/2/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/3/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/4/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/5/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/6/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/7/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/8/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/dlang/sponsor/9/website" target="_blank"><img src="https://opencollective.com/dlang/sponsor/9/avatar.svg"></a>