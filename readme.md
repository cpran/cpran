CPrAN
=====

A plugin manager for Praat
--------------------------

### The problem

This is an extended thought experiment.

One of the recurring problems with Praat is that the user community is
incredibly fragmented. Even though there is an active mailing list, there is
very little systematic sharing of code.

This has generated a large number of scripts and snippets that do very similar
things, that get recycled and re-written and recombined into other scripts,
often by people who only half-understand what the original scripts were doing.

This is a problem for a number of reasons.

First, because we are doomed to constantly reinvent the wheel. There is only one
channel that can be considered a unified way to announce new projects and script
suites, namely, the mailing list. But few users if any actually use it for that
purpose, and with good reason: it's not very well suited for that task.
Uploading documents is bothersome, accessing requires signing in, and it's not
normally advertised as a space for that sort of things.

Second, because the scripts that result from this process are normally not very
good. They are written to do one thing, in one environment, with very little
thought about portability or features that will facilitate code-reuse. There is
no set of common good practices, no notion of the value of writing a script that
works well with others.

And third, because this works against one of the main goals of being able to
write scripts in the first place: reproducibility. Most of the scripts out there
tend to devolve into a large mess, which is hard to read, hard to understand,
and hard to maintain. And as expected, are shelved to be forgotten, or shared
with people who will have to go through the impossible task of making sense of
the whole thing. Which brings us back to the point made above.

### A solution?

The ideal solution for this is a package manager, in the tradition of CPAN,
CRAN, CTAN, and the many others that have developed for other systems, like
`pip` for python, `bower` for javascript, etc.

One could imagine one such central repository for Praat plugins (a CPrAN, if you
will) that concentrated code submissions that could be held up to some standard
in terms of a guarantee of interoperability, level of documentation, etc.

The repository would have an API that would allow any compliant client to
search, browse and download the hosted plugins, as well as keep them up to date
and remove them if desired. If the idea works, then this client could eventually
be included in the code-base of Praat itself, which would make integration all
the easier.

Such a system would not necessarily solve the problems highlighted above, but it
would generate a platform that would allow those problems to find a solution; a
platform that today does not exist. It would also rbe the most economic, since
it makes use of features that are already existing in the Praat ecosystem:
plugins  would take care of the packaging, and making use of its scripting
language would ensure cross-platform compatibility.

### Let's get started

The plugins hosted under <https://gitlab.com/cpran> are a possible starting
point for such an effort. But a lot needs to be discussed in terms of the design
of this system. This is an open invitation to talk about this, and about how to
make this work.

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

`cpran update` maintains a local list of the latest versions of use CPrAN
plugins, and should be the first command to run to make sure the list is up to
date. In this sense, it behaves like `apt-get update`.

Queries to this list are done through `cpran search`, which also makes it
possible to search through the plugins that are already installed. In that
sense, it serves both as `apt-cache search` to look for plugins to install, and
as `dpkg -l | grep ii` to show what plugins are already installed. When used in
this latter form, it will show the local versions as well as those of the remote
repository.

`cpran show` displays information about specific plugins. A number of plugins
can be specified at the same time, and their description will be printed as a
stream. It is the equivalent of `apt-cache show`.

`cpran remove` takes care of deleting plugins from disk, and in that sense
behaves like  `apt-get remove --purge`.

Installation is done through `cpran install`, which behaves like
`apt-get install`. And upgrading plugins to their most recent version is done
with `cpran upgrade`, which acts like `apt-get upgrade`.

### Installation

As this is an experimental version, it is still in its testing stages. If you
want to help by running it on your own machine, comments are very welcome. Since
Praat is cross-platform, it is extremely important for CPrAN to also work in
those same platforms, and care has been made to write it so that that is
possible.

The absolute easiest way to install it is to use `git`. Go to the Praat
[preferences directory][] and run
`git clone https://gitlab.com/cpran/plugin_cpran.git`. Then skip the next
paragraph and read on.

Alternatively, you can download the contents of [this repositoru][zip]. It
should be able to run from anywhere in your computer, but it's probably better
if you save it as you would with any other plugin: in the [preferences
directory][]. Please note that some testing seems to indicate that this is
particularly important across filesystem barriers, so at the very least make
sure it is in the same filesystem as the preferences directory.

The important script to run is `cpran`, in the root of this plugin.

You will need Perl to run it. If you are on GNU/Linux then chances are you
already have it. If not, check your distro's documentation on how to get it. If
you are on Windows, you can find instructions on how to install it
[here][winperl]. If you are on Mac, please see [here][macperl].

You will also need to install some modules from CPAN. When you install Perl,
chances are you'll also get `cpan`. Check the appropriate documentation to see
how to install CPAN modules. Note you'll need a compiler to do this (but it's
normally a pretty automatic task).

These are the modules that are currently needed:

* App::Cmd
* Archive::Tar
* Carp
* Data::Dumper
* Encode
* File::Copy
* File::Path
* File::Slurp
* File::Temp
* GitLab::API::v3
* Graph
* LWP::Simple
* LWP::UserAgent
* MIME::Base64
* Path::Class
* Text::Table

And you should be able to just paste this line and install them (although be
advised that it will take a while):

    cpan App::Cmd Archive::Tar Carp Data::Dumper Encode File::Copy File::Path File::Slurp File::Temp GitLab::API::v3 Graph LWP::UserAgent LWP::Simple MIME::Base64 Path::Class Text::Table

Once all that is done, you should be able to run `cpran.pl` from the command
line. To make sure that all is well, try running `perl cpran.pl --version`.
If that command still fails and you've followed all the steps so far, go check
out the [issues][] page for similar problems, or open a new issue to get help. 

You can get some basic usage information by running `perl cpran.pl help` or
`perl cpran.pl help <command>`, where `<command>` is the name of the command
you want help with. Or you can use `perldoc cpran.pl` or check out the [markdown
version of the POD][mainpod] for much more detailed information.

And make sure to report any problems or successes you might have on your setup!

[gitlab]: https://gitlab.com
[bower]: https://github.com/bower/bower
[zip]: https://gitlab.com/cpran/plugin_cpran/repository/archive.zip?ref=master
[semver]: http://semver.org
[preferences directory]: http://www.fon.hum.uva.nl/praat/manual/preferences_directory.html
[winperl]: http://learn.perl.org/installing/windows.html
[macperl]: http://learn.perl.org/installing/osx.html
[issues]: https://gitlab.com/cpran/plugin_cpran/issues
[mainpod]: https://gitlab.com/cpran/plugin_cpran/blob/perl/main.md
