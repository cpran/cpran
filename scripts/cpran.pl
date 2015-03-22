#!/usr/bin/perl

use CPrAN;
CPrAN->run;

=encoding utf8

=head1 NAME

B<CPrAN> - A package manager for Praat

=head1 SYNOPSIS

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

=head1 DESCRIPTION

B<cpran> is the main script for an App::Cmd application to search, install,
remove and update Praat plugins.

=over

=item B<update>

See L<CPrAN::Command::update> for the full documentation.

=item B<search>

See L<CPrAN::Command::search> for the full documentation.

=item B<show>

See L<CPrAN::Command::show> for the full documentation.

=item B<install>

See L<CPrAN::Command::install> for the full documentation.

=item B<upgrade>

See L<CPrAN::Command::upgrade> for the full documentation.

=item B<remove>

See L<CPrAN::Command::remove> for the full documentation.

=back

=head1 FILES

=head2 The preferences directory

B<CPrAN> needs read and write access to I<Praat>'s preferences directory. The
exact location for this directory varies according to the platform, so B<CPrAN>
will keep the path to it in C<$CPrAN::PRAAT>.

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

        This long description is optional, but very useful to have. Line
        breaks in the long description will be converted to spaces, but you
        can start a new paragraph by using a blank line.

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
internally in C<$CPrAN::ROOT>. By default, it will be a directory named
C<.cpran> in the root of the B<CPrAN> plugin (C<$CPrAN::PRAAT/plugin_cpran>). In
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

L<CPrAN>, L<CPrAN::Command::remove>, L<CPrAN::Command::search>, 
L<CPrAN::Command::update>, L<CPrAN::Command::upgrade>, L<CPrAN::Command::show>,
L<CPrAN::Command::install>

=head1 VERSION

0.0.1

=cut
