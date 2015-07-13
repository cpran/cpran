# NAME

**CPrAN::Plugin** - Plugin class for CPrAN

# SYNOPSIS

my $plugin = CPrAN::Plugin->new( $name );

$plugin->is\_installed  ; checks for local copy
$plugin->is\_cpran      ; checks for presence of descriptor
$plugin->update        ; updates object's internal state

# DESCRIPTION

Objects of class `CPrAN::Plugin` represent plugins / packages for Praat,
distributable via CPrAN, its package manager. The class can represent any Praat
plugins, regardless of whether they are on CPrAN or not.

# METHODS

- **is\_cpran()**

    Checks if plugin has a descriptor that CPrAN can use.

- **is\_installed()**

    Checks if the plugin is installed or not.

- **update()**

    Updates the internal state of the plugin, to reflect any changes in disk that
    took place after the object's creation.

- remote\_id()

    Fetches the CPrAN remote id for the plugin.

- is\_latest()

    Compares the version on the locally installed copy of the plugin (if any) and
    the one reported by the remote descriptor on record by the client (if any).

    Returns true if installed version is the most recent the client knows about,
    false if there is a newer version, and undefined if there is no remote version
    to query.

- test()

    Runs tests for the plugin (if any). Returns the result of those tests.

- print(_FIELD_)

    Prints the contents of the plugin descriptors, either local or remote. These
    must be asked for by name. Any other names are an error.

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This module is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[CPrAN](cpran),
[CPrAN::Command::install](install),
[CPrAN::Command::remove](remove)
[CPrAN::Command::show](show),
[CPrAN::Command::search](search),
[CPrAN::Command::test](test),
[CPrAN::Command::update](update),
[CPrAN::Command::upgrade](upgrade),
