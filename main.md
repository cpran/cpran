# NAME

**CPrAN** - A package manager for Praat

# SYNOPSIS

cpran \[global options\] command \[options\] \[arguments\]

# DESCRIPTION

**cpran** is the main script for an App::Cmd application to search, install,
remove and update Praat plugins.

## Commands

- **update**

    See [CPrAN::Command::update](https://metacpan.org/pod/CPrAN::Command::update) for the full documentation.

- **search**

    See [CPrAN::Command::search](https://metacpan.org/pod/CPrAN::Command::search) for the full documentation.

- **show**

    See [CPrAN::Command::show](https://metacpan.org/pod/CPrAN::Command::show) for the full documentation.

- **install**

    See [CPrAN::Command::install](https://metacpan.org/pod/CPrAN::Command::install) for the full documentation.

- **upgrade**

    See [CPrAN::Command::upgrade](https://metacpan.org/pod/CPrAN::Command::upgrade) for the full documentation.

- **remove**

    See [CPrAN::Command::remove](https://metacpan.org/pod/CPrAN::Command::remove) for the full documentation.

## Options

- **--praat=PATH**

    Set the path to Praat preferences directory. See the FILES section for the
    platform-dependant default values if this is not set.

- **--cpran=PATH**

    Set the path to the CPrAN root. See the FILES section for more information on
    what is stored in the root.

    This option is useful if using **CPrAN** with an on-site collection of plugins.

- **--api-token=TOKEN**

    Set the private token for access to the GitLab API.

- **--api-url=URL**

    Set the URL of the GitLab API. This option is useful if using **CPrAN** with an
    on-site collection of plugins.

- **--api-group=ID**

    Set the id for the GitLab CPrAN group. This option is useful if using **CPrAN**
    with an on-site collection of plugins.

# EXAMPLES

    # Update the list of known plugins
    cpran update
    # Shows the entire list of known plugins
    cpran search .*
    # Search in the known plugin list for something
    cpran search something
    # Search in the installed plugin list for something
    cpran search -i something
    # Show the descriptor of a plugin by name
    cpran show name
    # Install a plugin by name
    cpran install name
    # Upgrade all plugins to their most recent version
    cpran update
    # Upgrade a plugin by name to its most recent version
    cpran update name
    # Remove a plugin by name from disk
    cpran remove name

# FILES

## The preferences directory

**CPrAN** needs read and write access to _Praat_'s preferences directory. The
exact location for this directory varies according to the platform, so **CPrAN**
will keep the path to it, accessible through CPrAN::praat().

Below are the default locations for the main supported platforms:

- _UNIX_

    `~/.praat-dir`

- _Macintosh_

    `/Users/username/Library/Preferences/Praat/Prefs`

- _Windows_

    `C:\Documents and Settings\username\Praat`

Where `username` is, of course, the name of the active user.

Functions like installed() and is\_plugin() look in this directory to get their
information.

## Plugin descriptors

**CPrAN** plugins are identified as such by the presence of a _plugin
descriptor_ in the plugin's root. The descriptor (named `cpran.yaml`) is a YAML
file with fields that identify the name and version of the plugin, what it does,
what its requirements are, etc.

A commented example is bundled with this module as `example.yaml`, but here is
a version stripped of comments, for simplicity:

    ---
    Plugin: name
    Homepage: https://example.com
    Version: 1.2.3
    Maintainer: A. N. Author <author@example.com>
    Depends:
      praat: 5.0.0+
    Recommends:
    License:
      - GPL3 <https://www.gnu.org/licenses/gpl-3.0.html>
      - MIT <http://opensource.org/licenses/MIT>
    Readme: readme.md
    Description:
      Short: an example of a plugin descriptor
      Long: >
        This file serves as an example of a CPrAN plugin descriptor.

        This long description is optional, but very useful to have. Line
        breaks in the long description will be converted to spaces, but you
        can start a new paragraph by using a blank line.

        Like so.

**CPrAN** uses YAML::XS to attempt to parse the descriptor. Any error in parsing
will be treated by **CPrAN** in the same way as if the file was missing, so it's
important to properly validate the descriptor beforehand.

## The plugin list

To keep track of available plugins, **CPrAN** keeps the descriptors for all the
plugins it knows about, and queries them for information when necessary. This is
the list that known() looks in, and the list from where the **show** command gets
its data.

The descriptors are saved in a **CPrAN** root folder whose path is stored
internally and accessible through CPrAN::root(). By default, it will be a directory named
`.cpran` in the root of the **CPrAN** plugin (CPrAN::praat() . '/plugin\_cpran'). In
that directory, the descriptors are renamed with the name of the plugin they
represent.

This list is updated with the **update** command.

# AUTHOR

José Joaquín Atria <jjatria@gmail.com>

# LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

CPrAN, CPrAN::Command::remove, CPrAN::Command::search,
CPrAN::Command::update, CPrAN::Command::upgrade, CPrAN::Command::show,
CPrAN::Command::install

## Packages used

- App::Cmd
- Archive::Tar
- Carp
- Config
- Data::Dumper
- Encode
- File::Copy
- File::Path
- File::Slurp
- File::Temp
- GitLab::API::v3
- Graph
- LWP::Simple
- MIME::Base64
- Path::Class
- Text::Table
- YAML::XS

# VERSION

0.0.1
