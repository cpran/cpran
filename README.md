# NAME

**CPrAN** - A package manager for Praat

# SYNOPSIS

    use CPrAN;
    CPrAN->run;

# DESCRIPTION

**CPrAN** is the parent class for an App::Cmd application to search, install,
remove and update Praat plugins.

As a App::Cmd application, use of this module is separated over a number of
different files. The main script invokes the root module and executes it, as in
the example given in the SYNOPSIS.

**CPrAN** commands (inhabiting the **CPrAN::Command** namespace) can call the
methods described below to perform general **CPrAN**-related actions.

# OPTIONS

- **--praat**=FILE

    The path to use as binary for Praat. See the FILES section for information
    on the platform-dependant default values used.

- **--pref-dir**=DIR

    The path to use as the preferences directory for Praat. See the FILES section
    for information on the platform-dependant default values used.

    This option used to be called `--praat`.

- **--root**=DIR

    The path to use as the CPrAN root directory. See the FILES section
    for information on the platform-dependant default values used.

    This option used to be called `--cpran`.

- **--token**=TOKEN
- **--group**=NUMBER
- **--url**=URL

    These options set the credentials to talk to the GitLab API to obtain the
    plugin archives and descriptors. As such, it is implementation-dependant, and is
    currently tied to GitLab.

    These options used to be called `--api-XXX`, where XXX is their current name.

- **--verbose**, **--v**

    Increase the verbosity of the output. This option can be called multiple times
    to make the program even more talkative.

- **--quiet**, **--q**

    Opposed to **--verbose**, this option _suppresses_ all output. If both options
    are set simultaneously, this one takes precedence.

- **--debug**, **--D**

    Enables the output of debug information. Like **--verbose**, this option can be
    used multiple times to increase the number of debug messages that are printed.

- \_yesno()

    Gets either a _yes_ or a _no_ answer from STDIN. As arguments, it first
    receives a reference to the options hash, followed by the default answer (ie,
    the answer that will be entered if the user simply presses enter).

        $self->yes(1);            # Will automatically say 'yes'
        print "Yes or no?";
        if ($self->_yesno( $default )) { print "You said yes\n" }
        else { print "You said no\n" }

    By default, responses matching /^y(es)?$/i are considered to be _yes_
    responses.

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015-2017 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](https://metacpan.org/pod/cpran),
[CPrAN::Plugin](https://metacpan.org/pod/plugin),
[CPrAN::Command::deps](https://metacpan.org/pod/deps),
[CPrAN::Command::init](https://metacpan.org/pod/init),
[CPrAN::Command::install](https://metacpan.org/pod/install),
[CPrAN::Command::list](https://metacpan.org/pod/list),
[CPrAN::Command::remove](https://metacpan.org/pod/remove),
[CPrAN::Command::search](https://metacpan.org/pod/search),
[CPrAN::Command::show](https://metacpan.org/pod/show),
[CPrAN::Command::test](https://metacpan.org/pod/test),
[CPrAN::Command::update](https://metacpan.org/pod/update),
[CPrAN::Command::upgrade](https://metacpan.org/pod/upgrade)
