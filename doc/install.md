# NAME

**install** - Install new CPrAN plugins

# SYNOPSIS

cpran install \[options\] \[arguments\]

# DESCRIPTION

Equivalent in spirit to apt-get install, this command checks the dependencies
of the specified plugins, schedules the installation of plugins needed or
requested, downloads them from the server, tests them, and finally installs
them.

Currently, no testing is done, and installation works sometimes in Windows.

Arguments to **install** must be at least one and optionally more plugin names.
Plugin names can be appended with a specific version number to request for
versioned installation, but this is not currently implemented. When it is, names
will likely be of the form `name-1.0.0`.

# EXAMPLES

    # Install some plugins
    cpran install myplugin someplugin
    # Install a specific version of a plugin (not implemented)
    cpran install someplugin-0.5.3
    # Re-install an installed plugin
    cpran install --force
    # Do not ask for confirmation
    cpran install --force -y

# OPTIONS

- **--yes, -y**

    Assumes yes for all questions.

- **--force**

    Tries to work around problems. For example, if an installed plugin is requested
    for installation, it re-installs it instead of refusing. When tests are enabled,
    **--force** should allow for installation regardless of test outcomes.

- **--debug**

    Print debug messages.

# METHODS

- **rebuild\_list()**

    Rebuild the plugin list. This method is just a wrapper around **update**, used
    for re-creating the list when CPrAN is used to install itself.

- **get\_archive()**

    Downloads a plugin's tarball from the server. Returns the name of the tarball on
    disk.

- **install()**

    Extract the downloaded tarball.

- **strip\_prefix()**

    Praat uses a rather clumsy method to identify plugins: it looks for directories
    in the preferences directory whose name begins with the strnig "plugin\_".
    However, this is conceptually _not_ part of the name.

    Since user's might be tempted to include it in the name of the plugin, we remove
    it, and issue a warning to slowly teach them to Do The Right Thing™

    The method takes the reference to a list of plugin names, and returns a
    reference to the same list, without the prefix.

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](cpran),
[CPrAN::Command::search](search),
[CPrAN::Command::show](show),
[CPrAN::Command::update](update),
[CPrAN::Command::upgrade](upgrade),
[CPrAN::Command::remove](remove)
