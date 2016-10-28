# POPFILE LOADABLE MODULE
package Services::IMAP;
use POPFile::Module;
use Services::IMAP::Client;
@ISA = ("POPFile::Module");
use Carp;
use Fcntl;

# ----------------------------------------------------------------------------
#
# IMAP.pm --- a module to use POPFile for an IMAP connection.
#
# Copyright (c) 2001-2011 John Graham-Cumming
#
#   $Revision: 3776 $
#
#   This file is part of POPFile
#
#   POPFile is free software; you can redistribute it and/or modify it
#   under the terms of version 2 of the GNU General Public License as
#   published by the Free Software Foundation.
#
#   POPFile is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with POPFile; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#   Originally created by   Manni Heumann (mannih2001@users.sourceforge.net)
#   Modified by             Sam Schinke (sschinke@users.sourceforge.net)
#   Patches by              David Lang (davidlang@users.sourceforge.net)
#   Moved location by       John Graham-Cumming (jgrahamc@users.sf.net)
#
#   The documentation for this module can be found on
#   http://popfile.sf.net/cgi-bin/wiki.pl?ExperimentalModules/Imap
#
# ----------------------------------------------------------------------------

use Digest::MD5 qw( md5_hex );
use strict;
use warnings;
use locale;

my $cfg_separator = "-->";

#----------------------------------------------------------------------------
# new
#
#   Class new() function
#----------------------------------------------------------------------------

sub new {
    my $type = shift;
    my $self = $type->SUPER::new();

    $self->name( 'imap' );

    $self->{classifier__} = 0;

    # Here are the variables used by this module:

    # A place to store the last response that the IMAP server sent us
    $self->{last_response__} = '';

    # A place to store the last command we sent to the server
    $self->{last_command__} = '';

    # The tag that preceeds any command we sent, actually just a simple counter var
    $self->{tag__} = 0;

    # A list of mailboxes on the server:
    $self->{mailboxes__} = [];

    # The session id for the current session:
    $self->{api_session__} = '';

    # A hash to hold per-folder data (watched and output flag + socket connection)
    # This data structure is extremely important to the work done by this
    # module, so don't mess with it!
    # The hash contains one key per service folder.
    # This key will return another hash. This time the keys are fixed and
    # can be {output} for an output folder
    # {watched} for a watched folder.
    # {imap} will hold a valid socket object for the connection of this folder.
    $self->{folders__} = ();

    # A flag that tells us that the folder list has changed
    $self->{folder_change_flag__} = 0;

    # A hash containing the hash values of messages that we encountered
    # during a single run through service().
    # If you provide a hash as a key and if that key exists, the value
    # will be the folder where the original message was placed (or left) in.
    $self->{hash_values__} = ();

    $self->{history__} = 0;

    $self->{imap_error} = '';

    return $self;
}



# ----------------------------------------------------------------------------
#
# initialize
#
# ----------------------------------------------------------------------------

sub initialize {
    my $self = shift;

    $self->config_( 'hostname', '' );
    $self->config_( 'port', 143 );
    $self->config_( 'login', '' );
    $self->config_( 'password', '' );
    $self->config_( 'update_interval', 20 );
    $self->config_( 'expunge', 0 );
    $self->config_( 'use_ssl', 0 );

    # Those next variables have getter/setter functions and should
    # not be used directly:

    $self->config_( 'watched_folders', "INBOX" );     # function watched_folders
    $self->config_( 'bucket_folder_mappings', '' );   # function folder_for_bucket
    $self->config_( 'uidvalidities', '' );            # function uid_validity
    $self->config_( 'uidnexts', '' );                 # function uid_next

    # Diabled by default
    $self->config_( 'enabled', 0 );

    # Training mode is disabled by default:
    $self->config_( 'training_mode', 0 );

    # Set the time stamp for the last update to the current time
    # minus the update interval so that we will connect as soon
    # as service() is called for the first time.
    $self->{last_update__} = time - $self->config_( 'update_interval' );

    return $self->SUPER::initialize();
}




# ----------------------------------------------------------------------------
#
# Start. Get's called by the loader and makes us run.
#
#   We try to connect to our IMAP server here, and get a list of
#   folders / mailboxes, so we can populate the configuration UI.
#
# ----------------------------------------------------------------------------

sub start {
    my $self = shift;

    if ( $self->config_( 'enabled' ) == 0 ) {
        return 2;
    }

    $self->register_configuration_item_( 'configuration',
                                         'imap_0_connection_details',
                                         'imap-connection-details.thtml',
                                         $self );

    $self->register_configuration_item_( 'configuration',
                                         'imap_1_watch_folders',
                                         'imap-watch-folders.thtml',
                                         $self );

    $self->register_configuration_item_( 'configuration',
                                         'imap_2_watch_more_folders',
                                         'imap-watch-more-folders.thtml',
                                         $self );

    $self->register_configuration_item_( 'configuration',
                                         'imap_3_bucket_folders',
                                         'imap-bucket-folders.thtml',
                                         $self );

    $self->register_configuration_item_( 'configuration',
                                         'imap_4_update_mailbox_list',
                                         'imap-update-mailbox-list.thtml',
                                         $self );

    $self->register_configuration_item_( 'configuration',
                                         'imap_5_options',
                                         'imap-options.thtml',
                                         $self );

    return $self->SUPER::start();
}



# ----------------------------------------------------------------------------
# stop
#
#   Clean up - release the session key
#
# ----------------------------------------------------------------------------

sub stop {
    my $self = shift;

    $self->disconnect_folders__();
}


# ----------------------------------------------------------------------------
#
# service
#
#   This get's frequently called by the framework.
#   It checks whether our checking interval has elapsed and if it has,
#   it goes to work.
#
# ----------------------------------------------------------------------------

sub service {
    my $self = shift;

    if ( time - $self->{last_update__} >= $self->config_( 'update_interval' ) ) {

        # Since the IMAP-Client module can throw an exception, i.e. die if
        # it detects a lost connection, we eval the following code to be able
        # to catch the exception. We also tell Perl to ignore broken pipes.

        eval {
            local $SIG{'PIPE'} = 'IGNORE';
            local $SIG{'__DIE__'};

            if ( $self->config_( 'training_mode' ) == 1 ) {
                $self->train_on_archive__();
            }
            else {

                # If we haven't yet set up a list of serviced folders,
                # or if the list was changed by the user, build up a
                # list of folder in $self->{folders__}
                if ( ( keys %{$self->{folders__}} == 0 ) || ( $self->{folder_change_flag__} == 1 ) ) {
                    $self->build_folder_list__();
                }

                $self->connect_server__();

                # Reset the hash containing the hash values we have seen the
                # last time through service.
                $self->{hash_values__} = ();

                # Now do the real job
                foreach my $folder ( keys %{$self->{folders__}} ) {
                    if ( exists $self->{folders__}{$folder}{imap} ) {
                        $self->scan_folder( $folder );
                    }
                }
            }
        };
        # if an exception occurred, we try to catch it here
        if ( $@ ) {
            $self->disconnect_folders__();
            # If we caught an exception, we better reset training_mode
            $self->config_( 'training_mode', 0 );

            # say__() and get_response__() will die with this message:
            if ( $@ =~ /^POPFILE-IMAP-EXCEPTION: (.+\)\))/s ) {
                $self->log_( 0, $1 );
            }
            # If we didn't die but somebody else did, we have empathy.
            else {
                die $@;
            }
        }
        # Save the current time.
        $self->{last_update__} = time;
    }

    return 1;
}


#----------------------------------------------------------------------------
# build_folder_list__
#
#   This function builds a list of all the folders that we have to care
#   about. This list consists of the folders we are watching for new mail
#   and of the folders that we are watching for reclassification requests.
#   The complete list is stored in a hash: $self->{folders__}.
#   The keys in this hash are the names of our folders, the values represent
#   flags. Currently, the flags can be
#       {watched} for watched folders and
#       {output} for output/bucket folders.
#   The function connect_folders__() will later add an {imap} key that will
#   hold the connection for that folder.
#
# arguments:
#   none.
#
# return value:
#   none.
#----------------------------------------------------------------------------

sub build_folder_list__ {
    my $self = shift;

    $self->log_( 1, "Building list of serviced folders." );

    # At this point, we simply reset the folders hash.
    # This isn't really elegant because it will leave dangling connections
    # if we have already been connected. But I trust in Perl's garbage collection
    # and keep my fingers crossed.

    %{$self->{folders__}} = ();

    # watched folders
    foreach my $folder ( $self->watched_folders__() ) {
        $self->{folders__}{$folder}{watched} = 1;
    }

    # output folders
    foreach my $bucket ( $self->classifier()->get_all_buckets( $self->api_session() ) ) {

        my $folder = $self->folder_for_bucket__( $bucket );

        if ( defined $folder ) {
            $self->{folders__}{$folder}{output} = $bucket;
        }
    }

    # If this is a new POPFile installation that isn't yet
    # configured, our hash will have exactly one key now
    # which will point to the INBOX. Since this isn't enough
    # to do anything meaningful, we simply reset the hash:

    if ( ( keys %{$self->{folders__}} ) == 1 ) {
        %{$self->{folders__}} = ();
    }

    # Reset the folder change flag
    $self->{folder_change_flag__} = 0;
}


# ----------------------------------------------------------------------------
#
# connect_server__ - Connect to the IMAP server if we are only using a single
#                    connection. The method will connect to the server, login
#                    retrieve the list of mailboxes and do a status on each
#                    of the folders that we are interested in to see whether
#                    the UIDVALIDITY has changed.
#
# IN:  -
# OUT: will die on failure
# ----------------------------------------------------------------------------

sub connect_server__ {
    my $self = shift;

    # Establish a single connection but gather all the data
    # we need for each folder.

    my $imap = undef;

    foreach my $folder ( keys %{$self->{folders__}} ) {
        # We may already have a valid connection:
        if ( exists $self->{folders__}{$folder}{imap} ) {
            last;
        }
        # The folder may be write-only:
        if ( exists $self->{folders__}{$folder}{output}
                &&
            ! exists $self->{folders__}{$folder}{watched}
                &&
            $self->classifier()->is_pseudo_bucket( $self->api_session(),
                        $self->{folders__}{$folder}{output} ) ) {
                next;
        }

        # We may have to create a fresh connection here.
        if ( ! defined $imap ) {
            # Have we got a stored active connection?
            $imap = $self->{folders__}{$folder}{imap};

            # Nope, must be the first time we end up here.
            if ( ! defined $imap ) {
                $imap = $self->new_imap_client();
                if ( $imap ) {
                    $self->{folders__}{$folder}{imap} = $imap;
                }
                else {
                    die "POPFILE-IMAP-EXCEPTION: Could not connect: $self->{imap_error} " . __FILE__ . '(' . __LINE__ . '))';
                }
            }
        }

        # Build a list of IMAP mailboxes if we haven't already got one:
        unless ( @{$self->{mailboxes__}} ) {
            @{$self->{mailboxes__}} = $imap->get_mailbox_list();
        }

        # Do a STATUS to check UIDVALIDITY and UIDNEXT
        my $info = $imap->status( $folder );
        my $uidnext = $info->{UIDNEXT};
        my $uidvalidity = $info->{UIDVALIDITY};

        if ( defined $uidvalidity && defined $uidnext ) {
            $self->{folders__}{$folder}{imap} = $imap;

            # If we already have a UIDVALIDITY value stored,
            # we compare the old and the new value.
            if ( defined $imap->uid_validity( $folder ) ) {
                if ( $imap->check_uidvalidity( $folder, $uidvalidity ) ) {
                    # That's the nice case.
                    # But let's make sure that our UIDNEXT value is also valid
                    unless ( defined $imap->uid_next( $folder ) ) {
                        $self->log_( 0, "Detected invalid UIDNEXT configuration value for folder $folder. Some new messages might have been skipped." );
                        $imap->uid_next( $folder, $uidnext );
                    }
                }
                else {
                    # The validity has changed, we log this and update our stored
                    # values for UIDNEXT and UIDVALIDITY
                    $self->log_( 0, "Changed UIDVALIDITY for folder $folder. Some new messages might have been skipped." );
                    $imap->uid_validity( $folder, $uidvalidity );
                    $imap->uid_next( $folder, $uidnext );
                }
            }
            else {
                # We don't have a stored value, so let's change that.
                $self->log_( 0, "Storing UIDVALIDITY for folder $folder." );
                $imap->uid_validity( $folder, $uidvalidity );
                $imap->uid_next( $folder, $uidnext );
            }
        }
        else {
            $self->log_( 0, "Could not STATUS folder $folder." );
            $imap->logout();
            die "POPFILE-IMAP-EXCEPTION: Could not get a STATUS for IMAP folder $folder (" . __FILE__ . '(' . __LINE__ . '))';
        }
    }
}


# ----------------------------------------------------------------------------
#
# disconnect_folders__
#
#   The test suite needs a way to disconnect all the folders after one test is
#   done and the next test needs to be done with different settings.
#
# ----------------------------------------------------------------------------

sub disconnect_folders__ {
    my $self = shift;

    $self->log_( 1, "Trying to disconnect all connections." );

    foreach my $folder ( keys %{$self->{folders__}} ) {

        my $imap = $self->{folders__}{$folder}{imap};
        if ( defined $imap  && $imap->connected() ) {
            # Workaround for POPFile crashes when disconnecting from server
            eval {
                $imap->logout( $folder );
            };
        }
    }
    %{$self->{folders__}} = ();
}


# ----------------------------------------------------------------------------
#
# scan_folder
#
#   This function scans a folder on the IMAP server.
#   According to the attributes of a folder (watched, output), and the attributes
#   of the message (new, classified, etc) it then decides what to do with the
#   messages.
#   There are currently three possible actions:
#       1. Classify the message and move to output folder
#       2. Reclassify message
#       3. Ignore message (if you want to call that an action)
#
# Arguments:
#
#   $folder: The folder to scan.
#
# ----------------------------------------------------------------------------

sub scan_folder {
    my $self   = shift;
    my $folder = shift;

    # make the flags more accessible.
    my $is_watched = ( exists $self->{folders__}{$folder}{watched} ) ? 1 : 0;
    my $is_output  = ( exists $self->{folders__}{$folder}{output } ) ? $self->{folders__}{$folder}{output} : '';

    $self->log_( 1, "Looking for new messages in folder $folder." );

    my $imap = $self->{folders__}{$folder}{imap};

    # Do a NOOP first. Certain implementations won't tell us about
    # new messages while we are connected and selected otherwise:
    if ( ! $imap->noop() ) {
        # Now what?
    }

    my $moved_message = 0;
    my @uids = ();

    @uids = $imap->get_new_message_list_unselected( $folder );

    # We now have a list of messages with UIDs greater than or equal
    # to our last stored UIDNEXT value (of course, the list might be
    # empty). Let's iterate over that list.

    foreach my $msg ( @uids ) {
        $self->log_( 1, "Found new message in folder $folder (UID: $msg)" );

        my $hash = $self->get_hash( $folder, $msg );
        $imap->uid_next( $folder, $msg + 1 );

        if ( ! defined $hash ) {
            $self->log_( 0, "Skipping message $msg." );
            next;
        }

        # Watch our for those pesky duplicate and triplicate spam messages:

        if ( exists $self->{hash_values__}{$hash} ) {
            my $destination = $self->{hash_values__}{$hash};
            if ( $destination ne $folder ) {
                $self->log_( 0, "Found duplicate hash value: $hash. Moving the message to $destination." );
                $imap->move_message( $msg, $destination );
                $moved_message++;
            }
            else {
                $self->log_( 0, "Found duplicate hash value: $hash. Ignoring duplicate in folder $folder." );
            }

            next;
        }

        # Find out what we are dealing with here:

        if ( $is_watched ) {
            if ( $self->can_classify__( $hash ) ) {

                my $result = $self->classify_message( $msg, $hash, $folder );

                if ( defined $result ) {
                    if ( $result ne '' ) {
                        $moved_message++;
                        $self->{hash_values__}{$hash} = $result;
                    }
                    else {
                        $self->{hash_values__}{$hash} = $folder;
                    }
                }
                next;
            }
        }

        if ( my $bucket = $is_output ) {
            if ( my $old_bucket = $self->can_reclassify__( $hash, $bucket ) ) {
                my $result = $self->reclassify_message( $folder, $msg, $old_bucket, $hash );
                next;
            }
        }

        # If we get here despite all those next statements, we do nothing and say so
        $self->log_( 1, "Ignoring message $msg" );
    }

    # After we are done with the folder, we issue an EXPUNGE command
    # if we were told to do so.
    if ( $moved_message && $self->config_( 'expunge' ) ) {
        $imap->expunge();
    }
}



# ----------------------------------------------------------------------------
#
# classify_message
#
#   This function takes a message UID and then tries to classify the corresponding
#   message to a POPFile bucket. It delegates all the house-keeping that keeps
#   the POPFile statistics up to date to helper functions, but the house-keeping
#   is done. The caller need not worry about this.
#
# Arguments:
#
#   $msg:    UID of the message (the IMAP folder must be SELECTed)
#   $hash:   The hash of the message as computed by get_hash()
#   $folder: The name of the folder on the server in which this message was found
#
# Return value:
#
#   undef on error
#   The name of the destination folder if the message was moved
#   The emtpy string if the message was not moved
#
# ----------------------------------------------------------------------------

sub classify_message {
    my $self   = shift;
    my $msg    = shift;
    my $hash   = shift;
    my $folder = shift;

    my $moved_a_msg = '';

    # open a temporary file that the classifier will
    # use to read the message in binary, read-write mode:
    my $pseudo_mailer;
    my $file = $self->get_user_path_( 'imap.tmp' );

    unless ( sysopen( $pseudo_mailer, $file, O_RDWR | O_CREAT ) ) {
        $self->log_( 0, "Unable to open temporary file $file. Nothing done to message $msg. ($!)" );

        return;
    }
    binmode $pseudo_mailer;

    # We don't retrieve the complete message, but handle
    # it in different parts.
    # Currently these parts are just headers and body.
    # But there is room for improvement here.
    # E.g. we could generate a list of parts by
    # first looking at the parts the message really has.

    my $imap = $self->{folders__}{$folder}{imap};

    PART:
    foreach my $part ( qw/ HEADER TEXT / ) {

        my ($ok, @lines ) = $imap->fetch_message_part( $msg, $part );

        unless ( $ok ) {
            $self->log_( 0, "Could not fetch the $part part of message $msg." );

            return;
        }

        foreach ( @lines ) {
            syswrite $pseudo_mailer, $_;
        }

        my ( $class, $slot, $magnet_used );

        # If we are dealing with the headers, let the
        # classifier have a non-save go:

        if ( $part eq 'HEADER' ) {
            sysseek $pseudo_mailer, 0, 0;
            ( $class, $slot, $magnet_used ) = $self->classifier()->classify_and_modify( $self->api_session(), $pseudo_mailer, undef, 1, '', undef, 0, undef );

            if ( $magnet_used ) {
                $self->log_( 0, "Message with slot $slot was classified as $class using a magnet." );
                syswrite $pseudo_mailer, "\nThis message was classified based on a magnet.\nThe body of the message was not retrieved from the server.\n";
            }
            else {
                next PART;
            }
        }

        # We will only get here if the message was magnetized or we
        # are looking at the complete message. Thus we let the classifier have
        # a look and make it save the message to history:
        sysseek $pseudo_mailer, 0, 0;

        ( $class, $slot, $magnet_used ) = $self->classifier()->classify_and_modify( $self->api_session(), $pseudo_mailer, undef, 0, '', undef, 0, undef );

        close $pseudo_mailer;
        unlink $file;

        if ( $magnet_used || $part eq 'TEXT' ) {

            # Move message:

            my $destination = $self->folder_for_bucket__( $class );
            if ( defined $destination ) {
                if ( $folder ne $destination ) {
                    $imap->move_message( $msg, $destination );
                    $moved_a_msg = $destination;
                }
            }
            else {
                $self->log_( 0, "Message cannot be moved because output folder for bucket $class is not defined." );
            }

            $self->log_( 0, "Message was classified as $class." );

            last PART;
        }
    }

    return $moved_a_msg;
}


# ----------------------------------------------------------------------------
#
# reclassify_message
#
#   This function takes a message UID and then tries to reclassify the corresponding
#   message from one POPFile bucket to another POPFile bucket. It delegates all the
#   house-keeping that keeps the POPFile statistics up to date to helper functions,
#   but the house-keeping
#   is done. The caller need not worry about this.
#
# Arguments:
#
#   $folder:     The folder that has received a reclassification request
#   $msg:        UID of the message (the IMAP folder must be SELECTed)
#   $old_bucket: The previous classification of the message
#   $hash:       The hash of the message as computed by get_hash()
#
# Return value:
#
#   undef on error
#   true if things went allright
#
# ----------------------------------------------------------------------------

sub reclassify_message {
    my $self = shift;
    my $folder = shift;
    my $msg = shift;
    my $old_bucket = shift;
    my $hash = shift;

    my $new_bucket = $self->{folders__}{$folder}{output};
    my $imap = $self->{folders__}{$folder}{imap};
    my ( $ok, @lines ) = $imap->fetch_message_part( $msg, '' );

    unless ( $ok ) {
        $self->log_( 0, "Could not fetch message $msg!" );
        return;
    }

    # We have to write the message to a temporary file.
    # I simply use "imap.tmp" as the file name here.

    my $file = $self->get_user_path_( 'imap.tmp' );
    if ( open my $TMP, '>', $file ) {
        foreach ( @lines ) {
            print $TMP $_;
        }
        close $TMP;

        my $slot = $self->history()->get_slot_from_hash( $hash );
        $self->classifier()->add_message_to_bucket( $self->api_session(), $new_bucket, $file );
        $self->classifier()->reclassified( $self->api_session(), $old_bucket, $new_bucket, 0 );
        $self->history()->change_slot_classification( $slot, $new_bucket, $self->api_session(), 0);

        $self->log_( 0, "Reclassified the message with UID $msg from bucket $old_bucket to bucket $new_bucket." );

        unlink $file;
    }
    else {
        $self->log_( 0, "Cannot open temp file $file" );
        return;
    }
}


# ----------------------------------------------------------------------------
#
#   (g|s)etters for configuration variables
#
#



# ----------------------------------------------------------------------------
#
#   folder_for_bucket__
#
#   Pass in a bucket name only to get a corresponding folder name
#   Pass in a bucket name and a folder name to set the pair
#
#---------------------------------------------------------------------------------------------

sub folder_for_bucket__ {
    my $self   = shift;
    my $bucket = shift;
    my $folder = shift;

    my $all = $self->config_( 'bucket_folder_mappings' );
    my %mapping = split /$cfg_separator/, $all;

    # set
    if ( $folder ) {
        $mapping{$bucket} = $folder;

        $all = '';
        while ( my ( $k, $v ) = each %mapping ) {
            $all .= "$k$cfg_separator$v$cfg_separator";
        }
        $self->config_( 'bucket_folder_mappings', $all );
    }
    # get
    else {
        if ( exists $mapping{$bucket} ) {
            return $mapping{$bucket};
        }
        else {
            return;
        }
    }
}


#---------------------------------------------------------------------------------------------
#
#   watched_folders__
#
#   Returns a list of watched folders when called with no arguments
#   Otherwise set the list of watched folders to whatever argument happens to be.
#
#---------------------------------------------------------------------------------------------

sub watched_folders__ {
    my $self = shift;
    my @folders = @_;

    my $all = $self->config_( 'watched_folders' );

    # set
    if ( @folders ) {
        $all = '';
        foreach ( @folders ) {
            $all .= "$_$cfg_separator";
        }
        $self->config_( 'watched_folders', $all );
    }
    # get
    else {
        return split /$cfg_separator/, $all;
    }
}



# ----------------------------------------------------------------------------
#
# classifier - Called by the framework to set our classifier
#               - call it without any arguments and you'll get the classifier
#
# ----------------------------------------------------------------------------

sub classifier {
    my $self = shift;
    my $classifier = shift;

    if ( defined $classifier ) {
        $self->{classifier__} = $classifier;
    }
    else {
        return $self->{classifier__};
    }
}


# ----------------------------------------------------------------------------
#
# history - Called by the framework to set our history module, called it
#           without any arguments to get the history module
#
# ----------------------------------------------------------------------------

sub history {
    my $self = shift;
    my $history = shift;

    if ( defined $history ) {
        $self->{history__} = $history;
    }
    else {
        return $self->{history__};
    }
}


# ----------------------------------------------------------------------------
#
# api_session - Return the API session key and get one if we haven't done so
#               already.
#
# ----------------------------------------------------------------------------

sub api_session {
    my $self = shift;

    if ( ! $self->{api_session__} ) {
        $self->{api_session__} = $self->classifier()->get_session_key( 'admin', '' );
    }

    return $self->{api_session__};
}


#----------------------------------------------------------------------------
# get hash
#
# Computes a hash of the MID and Date header lines of this message.
# Note that a folder on the server needs to be selected for this to work.
#
# Arguments:
#
#   $folder:    Name of the folder we are currently servicing.
#   $msg:       message UID
#
# Return value:
#   A string containing the hash value or undef on error.
#
#----------------------------------------------------------------------------

sub get_hash {
    my $self   = shift;
    my $folder = shift;
    my $msg    = shift;

    my $imap = $self->{folders__}{$folder}{imap};

    my ( $ok, @lines ) = $imap->fetch_message_part( $msg, "HEADER.FIELDS (Message-id Date Subject Received)" );

    if ( $ok ) {
        my %header;
        my $last;

        foreach ( @lines ) {

            s/[\r\n]//g;

            last if /^$/;

            if ( /^([^ \t]+):[ \t]*(.*)$/ ) {
                $last = lc $1;
                push @{$header{$last}}, $2;
            }
            else {
                if ( defined $last ) {
                    ${$header{$last}}[$#{$header{$last}}] .= $_;
                }
            }
        }

        my $mid      = ${$header{'message-id'}}[0];
        my $date     = ${$header{'date'}}[0];
        my $subject  = ${$header{'subject'}}[0];
        my $received = ${$header{'received'}}[0];

        my $hash = $self->history()->get_message_hash( $mid, $date, $subject, $received );

        $self->log_( 1, "Hashed message: $subject." );
        $self->log_( 1, "Message $msg has hash value $hash" );

        return $hash;
    }
    else {
        $self->log_( 0, "Could not FETCH the header fields of message $msg!" );
        return;
    }
}


#----------------------------------------------------------------------------
#   can_classify__
#
#   This function is a decider. It decides whether a message can be
#   classified if found in one of our watched folders or not.
#
# arguments:
#   $hash: The hash value for this message
#
# returns true or false
#----------------------------------------------------------------------------

sub can_classify__ {
    my $self = shift;
    my $hash = shift;

    my $slot = $self->history()->get_slot_from_hash( $hash );

    if ( $slot  ne '' ) {
        $self->log_( 1, "Message was already classified (slot $slot)." );
        return;
    }
    else {
        $self->log_( 1, "The message is not yet in history." );
        return 1;
    }
}


#----------------------------------------------------------------------------
#   can_reclassify__
#
# This function is a decider. It decides whether a message can be
# reclassified if found in one of our output folders or not.
#
# arguments:
#   $hash: The hash value for this message
#   $new_bucket: The name of the bucket the message should be classified to
#
# return value:
#   undef if the message should not be reclassified
#   the current classification if a reclassification is ok
#----------------------------------------------------------------------------

sub can_reclassify__ {
    my $self        = shift;
    my $hash        = shift;
    my $new_bucket  = shift;

    # We must already know the message
    my $slot = $self->history()->get_slot_from_hash( $hash );

    if ( $slot ne '' ) {
        my ( $id, $from, $to, $cc, $subject, $date, $hash, $inserted, $bucket, $reclassified, undef, $magnetized ) =
                    $self->history()->get_slot_fields( $slot );

        $self->log_( 2, "get_slot_fields returned the following information:" );
        $self->log_( 2, "id:            $id" );
        $self->log_( 2, "from:          $from" );
        $self->log_( 2, "to:            $to" );
        $self->log_( 2, "cc:            $cc" );
        $self->log_( 2, "subject:       $subject");
        $self->log_( 2, "date:          $date" );
        $self->log_( 2, "hash:          $hash" );
        $self->log_( 2, "inserted:      $inserted" );
        $self->log_( 2, "bucket:        $bucket" );
        $self->log_( 2, "reclassified:  $reclassified" );
        $self->log_( 2, "magnetized:    $magnetized" );

        # We cannot reclassify magnetized messages
        if ( ! $magnetized ) {

            # We must not reclassify a reclassified message
            if ( ! $reclassified ) {

                # new and old bucket must be different
                if ( $new_bucket ne $bucket ) {

                    # The new bucket must not be a pseudo-bucket
                    if ( ! $self->classifier()->is_pseudo_bucket( $self->api_session(), $new_bucket ) ) {
                        return $bucket;
                    }
                    else {
                        $self->log_( 1, "Will not reclassify to pseudo-bucket ($new_bucket)" );
                    }
                }
                else {
                    $self->log_( 1, "Will not reclassify to same bucket ($new_bucket)." );
                }
            }
            else {
                $self->log_( 1, "The message was already reclassified." );
            }
        }
        else {
            $self->log_( 1, "The message was classified using a manget and cannot be reclassified." );
        }
    }
    else {
        $self->log_( 1, "Message is unknown and cannot be reclassified." );
    }

    return;
}





# ----------------------------------------------------------------------------
#
# configure_item
#
#    $name            Name of this item
#    $templ           The loaded template that was passed as a parameter
#                     when registering
#    $language        Current language
#
# ----------------------------------------------------------------------------

sub configure_item {
    my $self = shift;
    my $name = shift;
    my $templ = shift;
    my $language = shift;

    # conection details
    if ( $name eq 'imap_0_connection_details' ) {
        $templ->param( 'IMAP_hostname', $self->config_( 'hostname' ) );
        $templ->param( 'IMAP_port',     $self->config_( 'port' ) );
        $templ->param( 'IMAP_login',    $self->config_( 'login' ) );
        $templ->param( 'IMAP_password', $self->config_( 'password' ) );
        $templ->param( 'IMAP_ssl_checked', $self->config_( 'use_ssl' ) ? 'checked="checked"' : '' );
    }

    # Which mailboxes/folders should we be watching?
    if ( $name eq 'imap_1_watch_folders' ) {

        # We can only configure this if we have a list of mailboxes on the server available
        if ( @{$self->{mailboxes__}} < 1 || ( ! $self->watched_folders__() ) ) {
            $templ->param( IMAP_if_mailboxes => 0 );
        }
        else {
            $templ->param( IMAP_if_mailboxes => 1 );

            # the following code will fill a loop containing another loop
            # The outer loop iterates over our watched folders,
            # the inner loop over all our mailboxes to fill the select form

            # Data for the outer loop, the inner loops data will be contained
            # in those data structures:

            my @loop_watched_folders = ();

            my $i = 0;

            # Loop over watched folder slot. One select form per watched folder
            # will be generated
            foreach my $folder ( $self->watched_folders__() ) {
                $i++;
                my %data_watched_folders = ();

                # inner loop data
                my @loop_mailboxes = ();

                # loop over IMAP mailboxes and generate a select element for reach one
                foreach my $mailbox ( @{$self->{mailboxes__}} ) {

                    # Populate inner loop entries:
                    my %data_mailboxes = ();

                    $data_mailboxes{IMAP_mailbox} = $mailbox;

                    # Is it currently selected?
                    if ( $folder eq $mailbox ) {
                        $data_mailboxes{IMAP_selected} = 'selected="selected"';
                    }
                    else {
                        $data_mailboxes{IMAP_selected} = '';
                    }

                    push @loop_mailboxes, \%data_mailboxes;
                }

                $data_watched_folders{IMAP_loop_mailboxes} = \@loop_mailboxes;
                $data_watched_folders{IMAP_loop_counter} = $i;
                $data_watched_folders{IMAP_WatchedFolder_Msg} = $$language{Imap_WatchedFolder};

                push @loop_watched_folders, \%data_watched_folders;
            }

            $templ->param( IMAP_loop_watched_folders => \@loop_watched_folders );
        }
    }

    # Give me another watched folder.
    if ( $name eq 'imap_2_watch_more_folders' ) {
        if ( @{$self->{mailboxes__}} < 1 ) {
            $templ->param( IMAP_if_mailboxes => 0 );
        }
        else {
            $templ->param( IMAP_if_mailboxes => 1 );
        }
    }


    # Which folder corresponds to which bucket?
    if ( $name eq 'imap_3_bucket_folders' ) {
        if ( @{$self->{mailboxes__}} < 1 ) {
            $templ->param( IMAP_if_mailboxes => 0 );
        }
        else {
            $templ->param( IMAP_if_mailboxes => 1 );

            my @buckets = $self->classifier()->get_all_buckets( $self->api_session() );

            my @outer_loop = ();

            foreach my $bucket ( @buckets ) {
                my %outer_data = ();
                my $output = $self->folder_for_bucket__( $bucket );

                $outer_data{IMAP_mailbox_defined} = (defined $output) ? 1 : 0;
                $outer_data{IMAP_Bucket_Header} = sprintf( $$language{Imap_Bucket2Folder}, $bucket );

                my @inner_loop = ();
                foreach my $mailbox ( @{$self->{mailboxes__}} ) {
                    my %inner_data = ();

                    $inner_data{IMAP_mailbox} = $mailbox;

                    if ( defined $output && $output eq $mailbox ) {
                        $inner_data{IMAP_selected} = 'selected="selected"';
                    }
                    else {
                        $inner_data{IMAP_selected} = '';
                    }

                    push @inner_loop, \%inner_data;
                }
                $outer_data{IMAP_loop_mailboxes} = \@inner_loop;
                $outer_data{IMAP_bucket} = $bucket;
                push @outer_loop, \%outer_data;
            }
            $templ->param( IMAP_loop_buckets => \@outer_loop );
        }
    }

    # Read the list of mailboxes from the server. Now!
    if ( $name eq 'imap_4_update_mailbox_list' ) {
        if ( $self->config_( 'hostname' ) eq '' ) {
            $templ->param( IMAP_if_connection_configured => 0 );
        }
        else {
            $templ->param( IMAP_if_connection_configured => 1 );
        }
    }

    # Various options for the IMAP module
    if ( $name eq 'imap_5_options' ) {

        # Are we expunging after moving messages?
        my $checked = $self->config_( 'expunge' ) ? 'checked="checked"' : '';
        $templ->param( IMAP_expunge_is_checked => $checked );

        # Update interval in seconds
        $templ->param( IMAP_interval => $self->config_( 'update_interval' ) );
    }
}



# ----------------------------------------------------------------------------
#
# validate_item
#
#    $name            The name of the item being configured, was passed in by the call
#                     to register_configuration_item
#    $templ           The loaded template
#    $language        The language currently in use
#    $form            Hash containing all form items
#
# ----------------------------------------------------------------------------

sub validate_item {
    my $self     = shift;
    my $name     = shift;
    my $templ    = shift;
    my $language = shift;
    my $form     = shift;

    # connection details
    if ( $name eq 'imap_0_connection_details' ) {
        return $self->validate_connection_details( $name, $templ, $language, $form );
    }

    # watched folders
    if ( $name eq 'imap_1_watch_folders' ) {
        if ( defined $form->{update_imap_1_watch_folders} ) {

            my $i = 1;
            my %folders;
            foreach ( $self->watched_folders__() ) {
                $folders{ $form->{"imap_folder_$i"} }++;
                $i++;
            }

            $self->watched_folders__( sort keys %folders );
            $self->{folder_change_flag__} = 1;
        }
        return;
    }

    # Add a watched folder
    if ( $name eq 'imap_2_watch_more_folders' ) {
        if ( defined $form->{imap_2_watch_more_folders} ) {
            my @current = $self->watched_folders__();
            push @current, 'INBOX';
            $self->watched_folders__( @current );
        }
        return;
    }

    # map buckets to folders
    if ( $name eq 'imap_3_bucket_folders' ) {
        if ( defined $form->{imap_3_bucket_folders} ) {

            # We have to make sure that there is only one bucket per folder
            # Multiple buckets cannot map to the same folder because how
            # could we reliably reclassify on move then?

            my %bucket2folder;
            my %folders;

            foreach my $key ( keys %$form ) {
                # match bucket name:
                if ( $key =~ /^imap_folder_for_(.+)$/ ) {
                    my $bucket = $1;
                    my $folder = $form->{ $key };

                    $bucket2folder{ $bucket } = $folder;
                    $folders{ $folder }++;
                }
            }

            my $bad = 0;
            while ( my ( $bucket, $folder ) = each %bucket2folder ) {

                if ( exists $folders{$folder} && $folders{ $folder } > 1 ) {
                    $bad = 1;
                }
                else {
                    $self->folder_for_bucket__( $bucket, $folder );
                    $self->{folder_change_flag__} = 1;
                }
            }
            $templ->param( IMAP_buckets_to_folders_if_error => $bad );
        }
        return;
    }

    # update the list of mailboxes
    if ( $name eq 'imap_4_update_mailbox_list' ) {
        return $self->validate_update_mailbox_list( $name, $templ, $language, $form );
    }

    # various options
    if ( $name eq 'imap_5_options' ) {

        if ( defined $form->{update_imap_5_options} ) {

            # expunge or not?
            if ( defined $form->{imap_options_expunge} ) {
                $self->config_( 'expunge', 1 );
            }
            else {
                $self->config_( 'expunge', 0 );
            }

            # update interval
            my $form_interval = $form->{imap_options_update_interval};
            if ( defined $form_interval ) {
                if ( $form_interval >= 10 && $form_interval <= 60*60 ) {
                    $self->config_( 'update_interval', $form_interval );
                    $templ->param( IMAP_if_interval_error => 0 );
                }
                else {
                    $templ->param( IMAP_if_interval_error => 1 );
                }
            }
            else {
                $templ->param( IMAP_if_interval_error => 1 );
            }
        }
        return;
    }

    $self->SUPER::validate_item( $name, $templ, $language, $form );
}


# ----------------------------------------------------------------------------
#
# validate_connection_details - Called by validate_item if we are validating
#                               the connection details
# ----------------------------------------------------------------------------

sub validate_connection_details {
    my $self     = shift;
    my $name     = shift;
    my $templ    = shift;
    my $language = shift;
    my $form     = shift;

    if ( defined $form->{update_imap_0_connection_details} ) {
        my $something_changed = undef;

        if ( $form->{imap_hostname} && $form->{imap_hostname} =~ /^\S+/ ) {
            $templ->param( IMAP_connection_if_hostname_error => 0 );
            if ( $self->config_( 'hostname' ) ne $form->{imap_hostname} ) {
                $self->config_( 'hostname', $form->{imap_hostname} );
                $something_changed = 1;
            }
        }
        else {
            $templ->param( IMAP_connection_if_hostname_error => 1 );
        }

        if ( $form->{imap_port} && $form->{imap_port} =~ m/^\d+$/ && $form->{imap_port} >= 1 && $form->{imap_port} < 65536 ) {
            if ( $self->config_( 'port' ) != $form->{imap_port} ) {
                $self->config_( 'port', $form->{imap_port} );
                $something_changed = 1;
            }
            $templ->param( IMAP_connection_if_port_error => 0 );
        }
        else {
            $templ->param( IMAP_connection_if_port_error => 1 );
        }

        if ( $form->{imap_login} ) {
            if ( $self->config_( 'login' ) ne $form->{imap_login} ) {
                $self->config_( 'login', $form->{imap_login} );
                $something_changed = 1;
            }
            $templ->param( IMAP_connection_if_login_error => 0 );
        }
        else {
            $templ->param( IMAP_connection_if_login_error => 1 );
        }

        if ( $form->{imap_password} ) {
            if ( $self->config_( 'password' ) ne $form->{imap_password} ) {
                $self->config_( 'password', $form->{imap_password} );
                $something_changed = 1;
            }
            $templ->param( IMAP_connection_if_password_error => 0 );
        }
        else {
            $templ->param( IMAP_connection_if_password_error => 1 );
        }

        my $use_ssl_now = $self->config_( 'use_ssl' );

        if ( $form->{imap_use_ssl} ) {
            $self->config_( 'use_ssl', 1 );
            if ( ! $use_ssl_now ) {
                $something_changed = 1;
            }
        }
        else {
            $self->config_( 'use_ssl', 0 );
            if ( $use_ssl_now ) {
                $something_changed = 1;
            }
        }

        if ( $something_changed ) {
            $self->log_( 1, 'Configuration has changed. Terminating any old connections.' );
            $self->disconnect_folders__();
        }
    }


    return;
}


# ----------------------------------------------------------------------------
#
# validate_update_mailbox_list - Called by validate_item if we are supposed
#                                to update our list of mailboxes
# ----------------------------------------------------------------------------

sub validate_update_mailbox_list {
    my $self     = shift;
    my $name     = shift;
    my $templ    = shift;
    my $language = shift;
    my $form     = shift;

    if ( defined $form->{do_imap_4_update_mailbox_list} ) {
        $self->log_( 2, 'Trying to update the list of mailboxes' );

        if ( $self->config_( 'hostname' )
            && $self->config_( 'login' )
            && $self->config_( 'login' )
            && $self->config_( 'port' )
            && $self->config_( 'password' ) ) {

            my $imap = $self->new_imap_client();
            if ( defined $imap ) {
                @{$self->{mailboxes__}} = $imap->get_mailbox_list();
                $imap->logout();
            }
            else {
                my $error = $self->{imap_error};

                if ( $error eq 'NO_CONNECT' ) {
                    $templ->param( IMAP_update_list_failed => 'Failed to connect to server. Please check the host name and port and make sure you are online.' );
                    $self->log_( 0, 'Could not connect to server.' );
                    # TODO: should be language__{Imap_UpdateError2}
                }
                elsif ( $error eq 'NO_LOGIN' ) {
                    $templ->param( IMAP_update_list_failed => 'Could not login. Verify your login name and password, please.' );
                    $self->log_( 0, 'Could not login.' );
                    # TODO: should be language__{Imap_UpdateError1}
                }
            }
        }
        else {
            $templ->param( IMAP_update_list_failed => 'Please configure the connection details first.' );
            # TODO: should be language__{Imap_UpdateError3}
        }
    }
    return;
}


# ----------------------------------------------------------------------------
#
# train_on_archive__ - Poorly supported method that will use all the mails
#                      in all our output folders to train POPFile on a bunch
#                      of pre-sorted messages.
# ----------------------------------------------------------------------------

sub train_on_archive__ {
    my $self = shift;

    $self->log_( 0, "Training on existing archive." );

    # Reset the folders hash and build it again.

    %{$self->{folders__}} = ();
    $self->build_folder_list__();

    # eliminate all watched folders
    foreach my $folder ( keys %{$self->{folders__}} ) {
        if ( exists $self->{folders__}{$folder}{watched} ) {
            delete $self->{folders__}{$folder};
        }
    }

    # Connect to server
    $self->connect_server__();

    foreach my $folder ( keys %{$self->{folders__}} ) {
        my $bucket = $self->{folders__}{$folder}{output};

        # Skip pseudobuckets and the INBOX
        next if $self->classifier()->is_pseudo_bucket( $self->api_session(), $bucket );
        next if $folder eq 'INBOX';

        my $imap = $self->{folders__}{$folder}{imap};

        # Set uidnext value to 1. We will train on all messages.
        $imap->uid_next( $folder, 1 );
        my @uids = $imap->get_new_message_list_unselected( $folder );

        $self->log_( 0, "Training on " . ( scalar @uids ) . " messages in folder $folder to bucket $bucket." );

        foreach my $msg ( @uids ) {
            my ( $ok, @lines ) = $imap->fetch_message_part( $msg, '' );
            $imap->uid_next( $folder, $msg );

            unless ( $ok ) {
                $self->log_( 0, "Could not fetch message $msg!" );
                next;
            }

            my $file = $self->get_user_path_( 'imap.tmp' );
            if ( open my $TMP, '>', $file ) {
                foreach ( @lines ) {
                    print $TMP "$_\n";
                }
                close $TMP;

                $self->classifier()->add_message_to_bucket( $self->api_session(), $bucket, $file );
                $self->log_( 0, "Training on the message with UID $msg to bucket $bucket." );

                unlink $file;
            }
            else {
                $self->log_( 0, "Cannot open temp file $file" );
                next;
            }
        }
    }

    # Again, reset folders__ hash.
    %{$self->{folders__}} = ();

    # And disable training mode so we won't do this again the next time service is called.
    $self->config_( 'training_mode', 0 );
}

# ----------------------------------------------------------------------------
#
# new_imap_client - Create a new object of type Services::IMAP::Client,
#                   connect to the server and logon.
#
# arguments: none.
# returns:   new Services::IMAP::Client object on success or undef on error
#
# The exact error is stored away in $self->{imap_error}.
# The possible errors are:
#    * NO_LOGIN:   login failed, wrong username/password
#    * NO_CONNECT: connection failed, have we got network access? Are we
#                  using the correct hostname or port? should we use ssl or not?
# ----------------------------------------------------------------------------

sub new_imap_client {
    my $self = shift;

    my $imap = Services::IMAP::Client->new(
                sub { $self->config_( @_ ) },
                $self->{logger__},
                sub { $self->global_config_( @_ ) },
    );

    if ( $imap ) {
        if ( $imap->connect() ) {
            if ( $imap->login() ) {
                return $imap;
            }
            else {
                $self->log_( 0, "Could not LOGIN." );
                $self->{imap_error} = 'NO_LOGIN';
            }
        }
        else {
            $self->log_( 0, "Could not CONNECT to server." );
            $self->{imap_error} = 'NO_CONNECT';
        }
    }
    else {
        $self->log_( 0, 'Could not create IMAP object!' );
        $self->{imap_error} = 'NO_OBJECT';
    }

    return;
}


1;
