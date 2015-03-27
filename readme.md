CPrAN
=====

A plugin manager for Praat
--------------------------

### Current implementation

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
> "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
> interpreted as described in [RFC 2119](http://tools.ietf.org/html/rfc2119).

The current implementation is written in Perl and uses [GitLab][] for its
server-side code. The interface is modeled after `apt` and `dpkg`, but should be
relatively familiar for most people who have used a package manager before.

Inspired by [bower][], the versioning of plugins is left to git, and each
[semantic versioning][semver]-compliant tag represents a new release.
Tags _MUST_ be in the `master` branch to be considered releases.

Each plugin that is in CPrAN _MUST_ have plugin descriptor written in
properly formatted YAML. This descriptor _MUST_ refer to the most recent
release, since this file will be used to keep track of what that most recent
version is.

Ideally, a package manager for Praat should be written in Praat, but that would
be a daunting task indeed. For this very first step of the project, it was
decided to move forward with a prototype that served as a sort of
proof-of-concept. Whether Perl remains the best tool for the job or not, will be
decided later. But details from the interface should be
implementation-independent, which leaves us free to try other alternatives in
the future.

As any good prototype, this is still in its testing stages. You can help by
running it on your own machine and sending in any feedback you might have
regarding both the design of the interface or (if you are technically oriented),
its implementation.

### Installation

Since Praat is cross-platform, it is extremely important for CPrAN to also work
in all the platforms Praat supports, and care has been made to write it so that
that is possible. However, this is a difficult task, so testing on as many
different platforms is recquired.

Now, on to the installation.

1.  You will need Perl to run the current version. Skip to step 3 if you
    already have Perl and the modules you'll need, or if you know how to set
    that up.

    If you are on GNU/Linux then chances are you already have it. If not, check
    your distro's documentation on how to get it.

    If you are on Windows, you can find instructions on how to install it
    [here][winperl].

    If you are on Mac, please see [here][macperl].

[macperl]: http://learn.perl.org/installing/osx.html
[winperl]: http://learn.perl.org/installing/windows.html

2.  Install the necessary CPAN modules.

    You should be able to just use this (acceptedly intimidating) line to
    install them. Depending on your system, it might take some time, but it
    should be a fairly automatic process.

        cpan App::Cmd Archive::Tar Carp Data::Dumper Encode File::Copy File::Path File::Slurp File::Temp GitLab::API::v3 Graph LWP::UserAgent LWP::Simple MIME::Base64 Path::Class Text::Table

3.  Install the CPrAN plugin

    The absolute easiest way to install it is to use `git`. If you know how to
    use git, go to the Praat [preferences directory][] and run

        git clone https://gitlab.com/cpran/plugin_cpran.git

    and you should be done.

    Alternatively, you can install it manually. Download the contents of [this
    repository][zip] and extract them to your [preferences directory][]. It
    should be able to run from anywhere in your computer, but it's probably
    better if you save it there, as you would with any other plugin.

    At the very least, try to save it so that it has direct access to the
    [preferences directory][]. It seems reading and writing over filesystem
    boundaries is difficult in some platforms.

4.  Run the client.

    The important script to run is `cpran.pl`, in the root of this plugin.

    To make sure that all is well, try running `perl cpran.pl --version` from the
    command line. If that command still fails and you've followed all steps so
    far, go check out the [issues][] page for similar problems, or open a new
    issue to get help.

    You can get some basic usage information by running `perl cpran.pl help` or
    `perl cpran.pl help <command>`, where `<command>` is the name of the command
    you want help with.

    You can also check the [wiki pages][wiki] for more detailed information about
    all available commands. Note that these pages are automatically generated
    from the documentation in the source of each command, so you can also check
    them offline with `perldoc <filename>`.

5.  Make sure to get back with reports of any problems or successes you might
    have on your setup!

[gitlab]: https://gitlab.com
[bower]: https://github.com/bower/bower
[zip]: https://gitlab.com/cpran/plugin_cpran/repository/archive.zip?ref=master
[semver]: http://semver.org
[preferences directory]: http://www.fon.hum.uva.nl/praat/manual/preferences_directory.html
[issues]: https://gitlab.com/cpran/plugin_cpran/issues
[mainpod]: https://gitlab.com/cpran/plugin_cpran/blob/master/doc/cpran.md
[wiki]: https://gitlab.com/cpran/plugin_cpran/wikis/home