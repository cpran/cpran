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

The ten plugins hosted under <https://gitlab.com/cpran> are a possible starting point for such an effort. But a lot needs to be discussed in terms of the design of this system. This is an open invitation to talk about this, and about how to make this work.


