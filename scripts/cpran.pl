#!/usr/bin/perl

use CPrAN;
CPrAN->run;

=encoding utf8

=head1 NAME

B<CPrAN> - A package manager for Praat

=head1 SYNOPSIS

cpran [global options] command [options] [arguments]

=head1 DESCRIPTION

B<cpran> is the main script for an App::Cmd application to search, install,
remove and update Praat plugins.

=head2 Commands

=over

=item B<update>

    cpran update [options]
    cpran update [options] [names]

CPrAN keeps a list of the available plugins, with information about each one,
including what its latest verion is and who is in charge of maintaining it.

As its name implies, the B<update> command takes care of keeping this list up to
date, so it should probably be the first command to run. It might be useful to
run it with the B<--verbose> option enabled, to keep track on what it is doing.

The list is currently implemented as individual files in the .cpran directory,
which is under the CPrAN root. See CPrAN::Command::update for the full
documentation.

=item B<search>

    cpran search [options] [regex]

B<search> makes it possible to look for plugins in the plugin list. If you are
not sure about the name of a plugin, you can use B<search> to explore the list
and try to find it. Or you can just use it to browse, to find unknown plugins
that might do what you need.

B<search> will return a list of all plugin names that match the provided regular
expression. Currently, it only attempts to match it in the plugin's name.

By using the B<--installed> option you can perform this search on your installed
plugins, which will additionally show you the local and remote versions, so you
can visually check if plugins any need upgrading.

See CPrAN::Command::search for the full documentation.

=item B<show>

    cpran show [options] [names]

Each plugin has a descriptor with general information about the plugin,
including its name, version, homepage, maintainer, description, etc. B<show>
allows you to read the contents of this file.

By default, it will show you the descriptors downloaded by B<update>, but you
can also use the B<--installed> option to read the descriptors of installed
plugins.

See CPrAN::Command::show for the full documentation.

=item B<install>

    cpran install [options] [names]

Once you've found a plugin with B<search> and figured out if you want to install
it or not thanks to B<show>, you can use B<install> to download a copy of the
latest version to your local Praat preferences directory. If the plugin's
descriptor specifies any dependencies, B<install> will also offer to install
these.

You also use B<install> to re-install a plugin that has already been installed
with the B<--force> option. This is useful if your local version somehow becomes
corrupted (eg, if you've accidentally deleted files from within it).

See CPrAN::Command::install for the full documentation.

=item B<upgrade>

    cpran upgrade
    cpran upgrade [options] [names]

If a new version of an installed plugin has been released, you can use
B<upgrade> to bring your local installation up to date. You can specify a name
to upgrade that individual plugin, or you can call it with no arguments, to
upgrade all plugins that are out of date.

See CPrAN::Command::upgrade for the full documentation.

=item B<remove>

    cpran remove [options] [names]

If you are not going to be using a plugin anymore, you can remove it with
B<remove>.

See CPrAN::Command::remove for the full documentation.

=back

=head2 Options

=over

=item B<--praat=PATH>

Set the path to Praat preferences directory. See the FILES section for the
platform-dependant default values if this is not set.

=item B<--cpran=PATH>

Set the path to the CPrAN root. See the FILES section for more information on
what is stored in the root.

This option is useful if using B<CPrAN> with an on-site collection of plugins.

=item B<--api-token=TOKEN>

Set the private token for access to the GitLab API.

=item B<--api-url=URL>

Set the URL of the GitLab API. This option is useful if using B<CPrAN> with an
on-site collection of plugins.

=item B<--api-group=ID>

Set the id for the GitLab CPrAN group. This option is useful if using B<CPrAN>
with an on-site collection of plugins.

=back

=head1 EXAMPLES

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
    cpran upgrade
    # Upgrade a plugin by name to its most recent version
    cpran upgrade name
    # Remove a plugin by name from disk
    cpran remove name

=head1 FILES

=head2 The preferences directory

B<CPrAN> needs read and write access to I<Praat>'s preferences directory. The
exact location for this directory varies according to the platform, so B<CPrAN>
will keep the path to it, accessible through CPrAN::praat().

Below are the default locations for the main supported platforms:

=over

=item I<UNIX>

C<~/.praat-dir>

=item I<Macintosh>

C</Users/username/Library/Preferences/Praat/Prefs>

=item I<Windows>

C<C:\Documents and Settings\username\Praat>

=back

Where C<username> is, of course, the name of the active user.

Functions like installed() and is_plugin() look in this directory to get their
information.

=head2 Plugin descriptors

B<CPrAN> plugins are identified as such by the presence of a I<plugin
descriptor> in the plugin's root. The descriptor (named C<cpran.yaml>) is a YAML
file with fields that identify the name and version of the plugin, what it does,
what its requirements are, etc.

A commented example is bundled with this module as C<example.yaml>, but here is
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

        This long description is optional, but very useful to have.
        Line breaks in the long description will be converted to
        spaces, but you can start a new paragraph by using a blank
        line.

        Like so.

B<CPrAN> uses YAML::XS to attempt to parse the descriptor. Any error in parsing
will be treated by B<CPrAN> in the same way as if the file was missing, so it's
important to properly validate the descriptor beforehand.

=head2 The plugin list

To keep track of available plugins, B<CPrAN> keeps the descriptors for all the
plugins it knows about, and queries them for information when necessary. This is
the list that known() looks in, and the list from where the B<show> command gets
its data.

The descriptors are saved in a B<CPrAN> root folder whose path is stored
internally and accessible through CPrAN::root(). By default, it will be a directory named
C<.cpran> in the root of the B<CPrAN> plugin (CPrAN::praat() . '/plugin_cpran'). In
that directory, the descriptors are renamed with the name of the plugin they
represent.

This list is updated with the B<update> command.

=head1 AUTHOR

José Joaquín Atria <jjatria@gmail.com>

=head1 LICENSE

Copyright 2015 José Joaquín Atria

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

CPrAN, CPrAN::Command::remove, CPrAN::Command::search,
CPrAN::Command::update, CPrAN::Command::upgrade, CPrAN::Command::show,
CPrAN::Command::install

=head2 Packages used

=over

=item App::Cmd

=item Archive::Tar

=item Carp

=item Config

=item Data::Dumper

=item Encode

=item File::Copy

=item File::Path

=item File::Slurp

=item File::Temp

=item GitLab::API::v3

=item Graph

=item LWP::Simple

=item MIME::Base64

=item Path::Class

=item Text::Table

=item YAML::XS

=back

=head1 VERSION

0.0.1

=cut
