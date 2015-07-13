# NAME

**remove** - Remove installed CPrAN plugins

# SYNOPSIS

cpran remove \[options\] \[arguments\]

# DESCRIPTION

Deletes a CPrAN plugin that has been installed.

Arguments to **remove** must be at least one and optionally more plugin names to
remove. For each named passed as argument, all contents of the directory named
"plugin\_<name>" will be removed from disk.

# EXAMPLES

    # Remove some plugins
    cpran remove oneplugin otherplugin
    # Do not ask for confirmation
    cpran remove -y oneplugin

# OPTIONS

- **--yes, -y**

    Assumes yes for all questions.

- **--force**

    Tries to work around problems.

- **--debug**

    Print debug messages.

- **--verbose**
- **--quiet**
- **--cautious**

# METHODS

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](cpran),
[CPrAN::Plugin](plugin),
[CPrAN::Command::install](install),
[CPrAN::Command::search](search),
[CPrAN::Command::show](show),
[CPrAN::Command::test](test),
[CPrAN::Command::update](update),
[CPrAN::Command::upgrade](upgrade)
