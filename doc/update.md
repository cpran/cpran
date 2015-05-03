# NAME

**update** - Update the catalog of CPrAN plugins

# SYNOPSIS

cpran update \[options\] \[arguments\]

# DESCRIPTION

Updates the list of plugins known to CPrAN, and information about their latest
versions.

**update** can take as argument a list of plugin names. If provided, only
information about those plugins will be retrieved. Otherwise, a complete list
will be downloaded. This second case is the recommended use.

# EXAMPLES

    # Updates the entire catalog printing information as it goes
    cpran update -v
    # Update information about specific plugins
    cpran update oneplugin otherplugin

# METHODS

- **fetch\_descriptor()**

    Fetches the descriptor of a plugin and writes it into an appropriately named
    file in the specified directory.

    Returns the serialised downloaded descriptor.

- **list\_projects()**

    Provided with a list of plugin search terms, it returns a list of serialised
    plugin objects. If the provided list is empty, it returns all the plugins it
    can find in the CPrAN group.

# OPTIONS

- **--verbose**

    Increase verbosity of output.

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
[CPrAN::Command::upgrade](upgrade),
[CPrAN::Command::remove](remove)
