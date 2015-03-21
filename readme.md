CPrAN
=====

A plugin manager for Praat
--------------------------

### The problem

This is an extended thought experiment.

One of the recurring problems with Praat is that the user community is incredibly fragmented. Even though there is an active mailing list, there is very little systematic sharing of code.

This has generated a large number of scripts and snippets that do very similar things, that get recycled and re-written and recombined into other scripts, often by people who only half-understand what the original scripts were doing.

This is a problem for a number of reasons.

First, because we are doomed to constantly reinvent the wheel. There is only one channel that can be considered a unified way to announce new projects and script suites, namely, the mailing list. But few users if any actually use it for that purpose, and with good reason: it's not very well suited for that task. Uploading documents is bothersome, accessing requires signing in, and it's not normally advertised as a space for that sort of things.

Second, because the scripts that result from this process are normally not very good. They are written to do one thing, in one environment, with very little thought about portability or features that will facilitate code-reuse. There is no set of common good practices, no notion of the value of writing a script that works well with others.

And third, because this works against one of the main goals of being able to write scripts in the first place: reproducibility. Most of the scripts out there tend to devolve into a large mess, which is hard to read, hard to understand, and hard to maintain. And as expected, are shelved to be forgotten, or shared with people who will have to go through the impossible task of making sense of the whole thing. Which brings us back to the point made above.

### A solution?

The ideal solution for this is a package manager, in the tradition of CPAN, CRAN, CTAN, and the many others that have developed for other systems, like `pip` for python, `bower` for javascript, etc.

One could imagine one such central repository for Praat plugins (a CPrAN, if you will) that concentrated code submissions that could be held up to some standard in terms of a guarantee of interoperability, level of documentation, etc.

The repository would have an API that would allow any compliant client to search, browse and download the hosted plugins, as well as keep them up to date and remove them if desired. If the idea works, then this client could eventually be included in the code-base of Praat itself, which would make integration all the easier.

Such a system would not necessarily solve the problems highlighted above, but it would generate a platform that would allow those problems to find a solution; a platform that today does not exist. It would also be the most economic, since it makes use of features that are already existing in the Praat ecosystem: plugins would take care of the packaging, and making use of its scripting language would ensure cross-platform compatibility.

### Let's get started

The plugins hosted under <https://gitlab.com/cpran> are a possible starting point for such an effort. But a lot needs to be discussed in terms of the design of this system. This is an open invitation to talk about this, and about how to make this work.

### Current work

The current experimental imlementation is written in Perl and uses 
[GitLab][] for its server-side code. The interface is modeled after `apt`
and `dpkg`.

Inspired by [bower][], the versioning of plugins is left to git, and each
[semantic versioning][semver]-compliant tag represents a new release.
Tags _MUST_ be in the `master` branch to be considered releases.

Each plugin that is in CPrAN _MUST_ have plugin descriptor written in
properly formatted YAML. This descriptor _MUST_ refer to the most recent
release. Maybe the best solution would be to set a git hook to
automatically generate these descriptors every time a new release is
tagged.

Like `apt-get update`, `cpran update` will maintain a local list of
the latest versions of use CPrAN plugins. Emulating `apt-cache search`,
`cpran search` will allow users to find specific plugins from within that
list, but its output will be more closely based on that of `dpkg`, so
that the same command can be used to search both remote and installed
versions.

Currently, output shows the name of the package, the version,
and the short description, but if this merged behaviour is desireable for
`cpran search`, then maybe a format like that of `tlmgr`, which shows 
both local and remote versions might be more suitable.

`cpran show` will serve as `apt-cache show`, to show the full descriptor 
of a specific plugin. `cpran remove` will work as `apt-get remove --purge`,
removing the entire plugin from memory.

Installation will be up to `cpran install`, which will behave like `apt-get install`.
And updating plugins will be the task of `cpran upgrade`, which will act
like `apt-get upgrade`.

[gitlab]: https://gitlab.com
[bower]: https://github.com/bower/bower
[semver]: http://semver.org
