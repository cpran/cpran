# NAME

**search** - Search CPrAN plugins

# SYNOPSIS

cpran search \[options\] \[arguments\]

# DESCRIPTION

Searches both the local and remote catalogs of CPrAN plugins.

The argument to **search** must be a single regular expression. Currently,
**search** tries to match it on the plugni's name, and returns a list of all
those who do.

When executed directly, it will print information on the matched plugins,
including their name, version, and a short description. If searching the locally
installed plugins, both the local and the remote versions will be displayed.

# EXAMPLES

    # Show all available plugins
    cpran search .*
    # Show installed plugins with the string "utils" in their name
    cpran search -i utils

# OPTIONS

- **--installed**

    Search the local (installed) CPrAN catalog.

- **--debug**

    Print debug messages.

# METHODS

- **make\_row()**

    Generates the appropriate line for a single plugin specified by name. Takes the
    name as an argument, and returns a list suitable to be plugged into a
    Text::Table object.

    The output depends on the current options: if **--installed** is enabled, the
    returned list will have both the local and the remote versions.

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](cpran),
[CPrAN::Command::install](install),
[CPrAN::Command::show](show),
[CPrAN::Command::update](update),
[CPrAN::Command::upgrade](upgrade),
[CPrAN::Command::remove](remove)
