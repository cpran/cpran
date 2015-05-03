# NAME

**upgrade** - Upgrades installed CPrAN plugins to their latest versions

# SYNOPSIS

cpran upgrade \[options\] \[arguments\]

# DESCRIPTION

Upgrades the specified CPrAN plugins to their latest known versions.

**upgrade** can take as argument a list of plugin names. If provided, only
those plugins will be upgraded. Otherwise, all installed plugins will be checked
for updates and upgraded. This second case should be the recommended use, but it
is not currently implemented.

# EXAMPLES

    # Upgrades all installed plugins
    cpran upgrade
    # Upgrade specific plugins
    cpran upgrade oneplugin otherplugin

# OPTIONS

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
[CPrAN::Command::show](show),
[CPrAN::Command::update](update),
[CPrAN::Command::remove](remove)
