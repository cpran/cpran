# NAME

**show** - Shows details of CPrAN plugins

# SYNOPSIS

cpran show \[options\] \[arguments\]

# DESCRIPTION

Shows the descriptor of specified plugins. Depending on the options used, it can
be used to display information about the latest available version, or the
currently installed version.

Arguments to **search** must be at least one and optionally more plugin names
whose descriptors will be displayed.

# EXAMPLES

    # Show details of a plugin
    cpran show oneplugin
    # Show the descriptors of many installed plugins
    cpran show -i oneplugin anotherplugin

# OPTIONS

- **--installed**

    Show the descriptor of installed CPrAN plugins.

# METHODS

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](cpran),
[CPrAN::Command::install](install),
[CPrAN::Command::search](search),
[CPrAN::Command::update](update),
[CPrAN::Command::upgrade](upgrade),
[CPrAN::Command::remove](remove)
