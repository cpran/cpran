CPrAN
=====

A plugin manager for Praat
--------------------------

**Just getting here? See [the wiki][wiki] for more information!**

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

[bower]: https://github.com/bower/bower
[gitlab]: https://gitlab.com
[semver]: http://semver.org

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

1.  **Install Perl**. You will need Perl to run the current version. Skip to step
    3 if you already have Perl and the modules you'll need, or if you know how to
    set that up.

    * If you are on GNU/Linux then chances are you already have it. If not, check
    your distro's documentation on how to get it.

    * If you are on Windows, you can find instructions on how to install it
    [here][winperl].

    * If you are on Mac, please see [here][macperl].

    > Note: also consider using [perlbrew][] or [plenv][] (or [berrybrew][] if on Windows),
    > which make it easy to set up user-specific perl installations.

[macperl]: http://learn.perl.org/installing/osx.html
[winperl]: http://learn.perl.org/installing/windows.html

2.  **Install the necessary CPAN modules**. These are the modules you'll need:

        * App::Cmd
        * Graph
        * Params::Validate
        * LWP::UserAgent
        * Path::Class
        * Text::FormatTable
        * URI
        * YAML::XS
        * JSON::Tiny
        * File::Which
        * HTML::Tree
        * Archive::Extract
        * TAP::Harness::Archive
        * LWP::Protocol::https
        * Git::Repository

    You should be able to install the packages using the CPAN client with a line like this:

        cpan App::Cmd Graph Params::Validate LWP::UserAgent Path::Class Text::FormatTable URI YAML::XS
        
    > Note: to avoid having to install packages at the system level (ie, with administrator
    > rights), consider using [plenv][] or [perlbrew][] (or [berrybrew][] if you are on
    > Windows). These are perl version managers that allow you to have multiple user-specific
    > perl installations.
    >
    > If you prefer a _purer_ version, see [here][faqlibrary] for information on how to
    > install packages as a normal user using regular CPAN, and [here][cpanmlibrary] for
    > the same using [`cpanminus`][cpanminus].

[cpanminus]: https://github.com/miyagawa/cpanminus    
[perlbrew]: https://perlbrew.pl
[plenv]: http://weblog.bulknews.net/post/58079418600/plenv-alternative-for-perlbrew    
[berrybrew]: http://perltricks.com/article/119/2014/10/10/Hello-berrybrew--the-Strawberry-Perl-version-manager
[faqlibrary]: http://learn.perl.org/faq/perlfaq8.html#How-do-I-keep-my-own-module-library-directory
[cpanmlibrary]: https://github.com/miyagawa/cpanminus#where-does-this-install-modules-to-do-i-need-root-access

3.  **Install the CPrAN plugin**

    The absolute easiest way to install it is to use `git`. If you know how to
    use `git`, go to the Praat [preferences directory][] and run

        git clone https://gitlab.com/cpran/plugin_cpran.git

    and you should be done.

[preferences directory]: http://www.fon.hum.uva.nl/praat/manual/preferences_directory.html    
    
    For a manual installation, download [this archive][zip] and extract its contents
    to your preferences directory. It should be able to run from anywhere in your
    computer, but it's probably better if you save it there, as you would with any
    other plugin.

[zip]: https://gitlab.com/cpran/plugin_cpran/repository/archive.zip?ref=master

    > Note: At the very least, try to save it so that it has direct access to the
    > preferences directory. It seems reading and writing over filesystem
    > boundaries is difficult in some platforms.

4.  **Run the client**

    The important script to run is `cpran.pl`, in the root of this plugin.

    To make sure that all is well, try running `perl cpran.pl --version` from the
    command line. If that command still fails and you've followed all steps so
    far, go check out the [issues][] page for similar problems, or open a new
    issue to get help.

[issues]: https://gitlab.com/cpran/plugin_cpran/issues    
    
    You can get some basic usage information by running `perl cpran.pl help` or
    `perl cpran.pl help <command>`, where `<command>` is the name of the command
    you want help with.

5.  **Making things easier**

    You should now be able to use CPrAN, but it will only work if you are in the
    CPrAN root folder (and you'll have to type a lot too!). You can make it easier
    to use by making a wrapper for the client script.

    If you are using `bash` (in Linux or Mac, or on Windows if using Cygwin), you
    can make an alias for the client like so (of course, replacing `/path/to/cpran`
    with the actual path):

        alias cpran='perl -I /path/to/cpran /path/to/cpran/cpran.pl'

    Please see [here][permalias] for information on how to make that alias
    permanent.

[permalias]: http://unix.stackexchange.com/a/183497

    If you are on Windows and not using Cygwin, copy the following line:

        perl -I /path/to/cpran /path/to/cpran/cpran.pl %*

    and save it as a file named `cpran.bat` somewhere in your `PATH`.

    > Note: You can the contents of your `PATH` by typing `echo %PATH%` into
    > a command line. If you want to add a new directory (eg, `C:\Users\yourname\bin`),
    > you can do it by typing
    >
    >     set PATH=%PATH%;C:\Users\yourname\bin
    >
    > or
    >
    >     setx PATH "%PATH%;C:\Users\yourname\bin"
    >
    > to make the changes permanent (only do this if you know what you are doing!).

    After that, you should be able to simply do `cpran --version`. 

    > Note: even though this is optional, the documentation will use this
    > shortened version throughout for simplicity. Future versions are
    > expected to make this automatic.

5.  **Profit**

    Check the contents of [the wiki][wiki] for more detailed information about
    all available commands. The [client page][cpran] is probably a good place to
    start. Note that those pages are automatically generated from the
    documentation in the source of each command, so you can also check them
    offline with `perldoc <filename>`.

    Make sure to [report any problems][issues] or successes you might
    have on your setup!

[wiki]: https://gitlab.com/cpran/plugin_cpran/wikis/home
[cpran]: https://gitlab.com/cpran/plugin_cpran/wikis/cpran
[issues]: https://gitlab.com/cpran/plugin_cpran/issues
