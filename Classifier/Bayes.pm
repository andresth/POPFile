# POPFILE LOADABLE MODULE
package Classifier::Bayes;

use POPFile::Module;
@ISA = ("POPFile::Module");

#----------------------------------------------------------------------------
#
# Bayes.pm --- Naive Bayes text classifier
#
# Copyright (c) 2001-2011 John Graham-Cumming
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
#   Modified by              Sam Schinke    (sschinke@users.sourceforge.net)
#   Merged with db code from Scott Leighton (helphand@users.sourceforge.net)
#
#----------------------------------------------------------------------------

use strict;
use warnings;
use locale;
use Classifier::MailParse;
use IO::Handle;
use DBI;
use Digest::MD5 qw( md5_hex );
use MIME::Base64;
use File::Copy;

# This is used to get the hostname of the current machine
# in a cross platform way

use Sys::Hostname;

# A handy variable containing the value of an EOL for networks

my $eol = "\015\012";

# Korean characters definition

my $ksc5601_sym = '(?:[\xA1-\xAC][\xA1-\xFE])';
my $ksc5601_han = '(?:[\xB0-\xC8][\xA1-\xFE])';
my $ksc5601_hanja  = '(?:[\xCA-\xFD][\xA1-\xFE])';
my $ksc5601 = "(?:$ksc5601_sym|$ksc5601_han|$ksc5601_hanja)";

my $eksc = "(?:$ksc5601|[\x81-\xC6][\x41-\xFE])"; #extended ksc

#----------------------------------------------------------------------------
# new
#
#   Class new() function
#----------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self = POPFile::Module->new();

    # Set this to 1 to get scores for individual words in message detail

    $self->{wordscores__}        = 0;

    # Choice for the format of the "word matrix" display.

    $self->{wmformat__}          = '';

    # Just our hostname

    $self->{hostname__}        = '';

    # File Handle for DBI database

    $self->{db__}                = {};

    $self->{history__}        = 0;

    # To save time we also 'prepare' some commonly used SQL statements
    # and cache them here, see the function db_connect__ for details

    $self->{db_get_buckets__} = 0;
    $self->{db_get_wordid__} = 0;
    $self->{db_get_word_count__} = 0;
    $self->{db_put_word_count__} = 0;
    $self->{db_get_unique_word_count__} = 0;
    $self->{db_get_bucket_word_counts__} = 0;
    $self->{db_get_bucket_word_count__} = 0;
    $self->{db_get_full_total__} = 0;
    $self->{db_get_bucket_parameter__} = 0;
    $self->{db_set_bucket_parameter__} = 0;
    $self->{db_get_bucket_parameter_default__} = 0;
    $self->{db_get_buckets_with_magnets__} = 0;
    $self->{db_delete_zero_words__} = 0;

    # Caches the name of each bucket and relates it to both the bucket
    # ID in the database and whether it is pseudo or not
    #
    # Subkeys used are:
    #
    # id     The bucket ID in the database
    # pseudo 1 if this is a pseudo bucket

    $self->{db_bucketid__}       = {};

    # Caches the IDs that map to parameter types

    $self->{db_parameterid__}    = {};

    # Caches looked up parameter values on a per bucket basis

    $self->{db_parameters__}     = {};

    # Used to parse mail messages

    $self->{parser__}            = new Classifier::MailParse;

    # The possible colors for buckets
    $self->{possible_colors__} = [ 'red',       'green',      'blue',       'brown', # PROFILE BLOCK START
                                   'orange',    'purple',     'magenta',    'gray',
                                   'plum',      'silver',     'pink',       'lightgreen',
                                   'lightblue', 'lightcyan',  'lightcoral', 'lightsalmon',
                                   'lightgrey', 'darkorange', 'darkcyan',   'feldspar',
                                   'black' ];                                        # PROFILE BLOCK STOP

    # Precomputed per bucket probabilities

    $self->{bucket_start__}      = {};

    # A very unlikely word

    $self->{not_likely__}        = {};

    # The expected corpus version
    #
    # DEPRECATED  This is only used when upgrading old flat file corpus files
    #             to the database

    $self->{corpus_version__}    = 1;

    # The unclassified cutoff this value means that the top
    # probabilily must be n times greater than the second probability,
    # default is 100 times more likely

    $self->{unclassified__}      = log(100);

    # Used to tell the caller whether a magnet was used in the last
    # mail classification

    $self->{magnet_used__}       = 0;
    $self->{magnet_detail__}     = 0;

    # This maps session keys (long strings) to user ids.  If there's
    # an entry here then the session key is valid and can be used in
    # the POPFile API.  See the methods get_session_key and
    # release_session_key for details

    $self->{api_sessions__}      = {};

    # Used to indicate whether we are using SQLite and what the full
    # path and name of the database is if we are.

    $self->{db_is_sqlite__}      = 0;
    $self->{db_name__}           = '';

    # Must call bless before attempting to call any methods

    bless $self, $type;

    $self->name( 'bayes' );

    return $self;
}

#----------------------------------------------------------------------------
#
# forked
#
# This is called inside a child process that has just forked, since
# the child needs access to the database we open it
#
#----------------------------------------------------------------------------
sub forked
{
    my ( $self ) = @_;

    $self->db_connect__();
}

#----------------------------------------------------------------------------
#
# childexit
#
# This is called inside a child process that is about to finish, since
# the child does not need access to the database we close it
#
#----------------------------------------------------------------------------
sub childexit
{
    my ( $self ) = @_;

    $self->db_disconnect__();
}

#----------------------------------------------------------------------------
#
# initialize
#
# Called to set up the Bayes module's parameters
#
#----------------------------------------------------------------------------
sub initialize
{
    my ( $self ) = @_;

    # This is the name for the database

    $self->config_( 'database', 'popfile.db' );

    # This is the 'connect' string used by DBI to connect to the
    # database, if you decide to change from using SQLite to some
    # other database (e.g. MySQL, Oracle, ... ) this *should* be all
    # you need to change.  The additional parameters user and auth are
    # needed for some databases.
    #
    # Note that the dbconnect string
    # will be interpolated before being passed to DBI and the variable
    # $dbname can be used within it and it resolves to the full path
    # to the database named in the database parameter above.

    $self->config_( 'dbconnect', 'dbi:SQLite:dbname=$dbname' );
    $self->config_( 'dbuser', '' ); $self->config_( 'dbauth', '' );

    # SQLite 1.05+ had some problems we've resolved.
    # This parameter is no longer used but we leave it for future use

    $self->config_( 'bad_sqlite_version', '4.0.0' );

    # No default unclassified weight is the number of times more sure
    # POPFile must be of the top class vs the second class, default is
    # 100 times more

    $self->config_( 'unclassified_weight', 100 );

    # The corpus is kept in the 'corpus' subfolder of POPFile
    #
    # DEPRECATED This is only used to find an old corpus that might
    # need to be upgraded

    $self->config_( 'corpus', 'corpus' );

    # The characters that appear before and after a subject
    # modification

    $self->config_( 'subject_mod_left',  '[' );
    $self->config_( 'subject_mod_right', ']' );

    # The position to insert a subject modification
    #  1 : Beginning of the subject (default)
    # -1 : End of the subject

    $self->config_( 'subject_mod_pos',  1 );

    # Get the hostname for use in the X-POPFile-Link header

    $self->{hostname__} = hostname;

    # Allow the user to override the hostname

    $self->config_( 'hostname', $self->{hostname__} );

    # If set to 1 then the X-POPFile-Link will have < > around the URL
    # (i.e. X-POPFile-Link: <http://foo.bar>) when set to 0 there are
    # none (i.e. X-POPFile-Link: http://foo.bar)

    $self->config_( 'xpl_angle', 0 );

    # This parameter is used when the UI is operating in Stealth Mode.
    # If left blank (the default setting) the X-POPFile-Link will use 127.0.0.1
    # otherwise it will use this string instead. The system's HOSTS file should
    # map the string to 127.0.0.1

    $self->config_( 'localhostname', '' );

    # This is a bit mask used to control options when we are using the
    # default SQLite database.  By default all the options are on.
    #
    # 1 = Asynchronous deletes
    # 2 = Backup database every hour

    $self->config_( 'sqlite_tweaks', 0xFFFFFFFF );

    # SQLite Journal mode.
    # To use this option, DBD::SQLite v1.20 or later is required.
    #
    #   delete   : Delete journal file after committing. (default)
    #              Slow but reliable.
    #   truncate : Truncate journal file to zero length after committing.
    #              Faster than 'delete' in some environment but less reliable.
    #   persist  : Persist journal file after committing.
    #              Faster than 'delete' in some environment but less reliable.
    #   memory   : Store journal file in memory.
    #              Very fast but can't rollback when process crashes.
    #   off      : Turn off journaling.
    #              Fastest of all but can't rollback.
    #
    # For more information about the journal mode, see:
    # http://www.sqlite.org/pragma.html#pragma_journal_mode

    $self->config_( 'sqlite_journal_mode', 'delete' );

    # Japanese wakachigaki parser ('kakasi' or 'mecab' or 'internal').

    $self->config_( 'nihongo_parser', 'kakasi' );

    $self->mq_register_( 'COMIT', $self );
    $self->mq_register_( 'RELSE', $self );

    # Register for the TICKD message which is sent hourly by the
    # Logger module.  We use this to hourly save the database if bit 1
    # of the sqlite_tweaks is set and we are using SQLite

    $self->mq_register_( 'TICKD', $self );

    return 1;
}

#----------------------------------------------------------------------------
#
# deliver
#
# Called by the message queue to deliver a message
#
# There is no return value from this method
#
#----------------------------------------------------------------------------
sub deliver
{
    my ( $self, $type, @message ) = @_;

    if ( $type eq 'COMIT' ) {
        $self->classified( $message[0], $message[2] );
    }

    if ( $type eq 'RELSE' ) {
        $self->release_session_key_private__( $message[0] );
    }

    if ( $type eq 'TICKD' ) {
        $self->backup_database__();
    }
}

#----------------------------------------------------------------------------
#
# start
#
# Called to start the Bayes module running
#
#----------------------------------------------------------------------------
sub start
{
    my ( $self ) = @_;

    # In Japanese or Korean or Chinese mode, explicitly set LC_COLLATE and
    # LC_CTYPE to C.
    #
    # This is to avoid Perl crash on Windows because default
    # LC_COLLATE of Japanese Win is Japanese_Japan.932(Shift_JIS),
    # which is different from the charset POPFile uses for Japanese
    # characters(EUC-JP).
    #
    # And on some configuration (e.g. Japanese Mac OS X), LC_CTYPE is set to
    # UTF-8 but POPFile uses EUC-JP encoding for Japanese. In this situation
    # lc() does not work correctly.

    my $language = $self->module_config_( 'html', 'language' ) || '';

    if ( $language =~ /^(Nihongo$|Korean$|Chinese)/ ) {
        use POSIX qw( locale_h );
        setlocale( LC_COLLATE, 'C' );
        setlocale( LC_CTYPE,   'C' );
    }

    # Pass in the current interface language for language specific parsing

    $self->{parser__}->{lang__}  = $language;
    $self->{unclassified__} = log( $self->config_( 'unclassified_weight' ) );

    if ( !$self->db_connect__() ) {
        return 0;
    }

    if ( $language eq 'Nihongo' ) {
        # Setup Nihongo (Japanese) parser.

        my $nihongo_parser = $self->config_( 'nihongo_parser' );

        $nihongo_parser = $self->{parser__}->setup_nihongo_parser( $nihongo_parser );

        $self->log_( 2, "Use Nihongo (Japanese) parser : $nihongo_parser" );
        $self->config_( 'nihongo_parser', $nihongo_parser );

        # Since Text::Kakasi is not thread-safe, we use it under the
        # control of a Mutex to avoid a crash if we are running on
        # Windows and using the fork.

        if ( ( $nihongo_parser eq 'kakasi' ) && ( $^O eq 'MSWin32' ) &&    # PROFILE BLOCK START
             ( ( ( $self->module_config_( 'pop3', 'enabled' ) ) &&
                 ( $self->module_config_( 'pop3', 'force_fork' ) ) ) ||
               ( ( $self->module_config_( 'nntp', 'enabled' ) ) &&
                 ( $self->module_config_( 'nntp', 'force_fork' ) ) ) ||
               ( ( $self->module_config_( 'smtp', 'enabled' ) ) &&
                 ( $self->module_config_( 'smtp', 'force_fork' ) ) ) ) ) { # PROFILE BLOCK STOP
            $self->{parser__}->{need_kakasi_mutex__} = 1; # PROFILE PLATFORM START MSWin32

            # Prepare the Mutex.
            require POPFile::Mutex;
            $self->{parser__}->{kakasi_mutex__} = new POPFile::Mutex( 'mailparse_kakasi' );
            $self->log_( 2, "Create mutex for Kakasi." ); # PROFILE PLATFORM STOP MSWin32
        }
    }

    $self->upgrade_predatabase_data__();

    return 1;
}

#----------------------------------------------------------------------------
#
# stop
#
# Called when POPFile is terminating
#
#----------------------------------------------------------------------------
sub stop
{
    my ( $self ) = @_;

    $self->db_disconnect__();
    delete $self->{parser__};
}

#----------------------------------------------------------------------------
#
# classified
#
# Called to inform the module about a classification event
#
# There is no return value from this method
#
#----------------------------------------------------------------------------
sub classified
{
    my ( $self, $session, $class ) = @_;

    $self->set_bucket_parameter( $session, $class, 'count',             # PROFILE BLOCK START
        $self->get_bucket_parameter( $session, $class, 'count' ) + 1 ); # PROFILE BLOCK STOP
}

#----------------------------------------------------------------------------
#
# backup_database__
#
# Called when the TICKD message is received each hour and if we are using
# the default SQLite database will make a copy with the .backup extension
#
#----------------------------------------------------------------------------
sub backup_database__
{
    my ( $self ) = @_;

    # If database backup is turned on and we are using SQLite then
    # backup the database by copying it

    if ( ( $self->config_( 'sqlite_tweaks' ) & 2 ) &&  # PROFILE BLOCK START
         $self->{db_is_sqlite__} ) {                   # PROFILE BLOCK STOP
        if ( !copy( $self->{db_name__}, $self->{db_name__} . ".backup" ) ) {
            $self->log_( 0, "Failed to backup database ".$self->{db_name__} );
        }
    }
}

#----------------------------------------------------------------------------
#
# tweak_sqlite
#
# Called when a module wants is to tweak access to the SQLite database.
#
# $tweak    The tweak to apply (a bit in the sqlite_tweaks mask)
# $state    1 to enable the tweak, 0 to disable
# $db       The db handle to tweak
#
#----------------------------------------------------------------------------
sub tweak_sqlite
{
    my ( $self, $tweak, $state, $db ) = @_;

    if ( $self->{db_is_sqlite__} &&
         ( $self->config_( 'sqlite_tweaks' ) & $tweak ) ) {

        $self->log_( 1, "Performing tweak $tweak to $state" );

        if ( $tweak == 1 ) {
            my $sync = $state?'off':'normal';
            $db->do( "pragma synchronous=$sync;" );
        }
    }
}

#----------------------------------------------------------------------------
#
# reclassified
#
# Called to inform the module about a reclassification from one bucket
# to another
#
# session            Valid API session
# bucket             The old bucket name
# newbucket          The new bucket name
# undo               1 if this is an undo operation
#
# There is no return value from this method
#
#----------------------------------------------------------------------------
sub reclassified
{
    my ( $self, $session, $bucket, $newbucket, $undo ) = @_;

    $self->log_( 0, "Reclassification from $bucket to $newbucket" );

    my $c = $undo?-1:1;

    if ( $bucket ne $newbucket ) {
        my $count = $self->get_bucket_parameter(           # PROFILE BLOCK START
                $session, $newbucket, 'count' );           # PROFILE BLOCK STOP
        my $newcount = $count + $c;
        $newcount = 0 if ( $newcount < 0 );
        $self->set_bucket_parameter(                        # PROFILE BLOCK START
                $session, $newbucket, 'count', $newcount ); # PROFILE BLOCK STOP

        $count = $self->get_bucket_parameter(              # PROFILE BLOCK START
                $session, $bucket, 'count' );              # PROFILE BLOCK STOP
        $newcount = $count - $c;
        $newcount = 0 if ( $newcount < 0 );
        $self->set_bucket_parameter(                       # PROFILE BLOCK START
                $session, $bucket, 'count', $newcount );   # PROFILE BLOCK STOP

        my $fncount = $self->get_bucket_parameter(         # PROFILE BLOCK START
                $session, $newbucket, 'fncount' );         # PROFILE BLOCK STOP
        my $newfncount = $fncount + $c;
        $newfncount = 0 if ( $newfncount < 0 );
        $self->set_bucket_parameter(                            # PROFILE BLOCK START
                $session, $newbucket, 'fncount', $newfncount ); # PROFILE BLOCK STOP

        my $fpcount = $self->get_bucket_parameter(         # PROFILE BLOCK START
                $session, $bucket, 'fpcount' );            # PROFILE BLOCK STOP
        my $newfpcount = $fpcount + $c;
        $newfpcount = 0 if ( $newfpcount < 0 );
        $self->set_bucket_parameter(                         # PROFILE BLOCK START
                $session, $bucket, 'fpcount', $newfpcount ); # PROFILE BLOCK STOP
    }
}

#----------------------------------------------------------------------------
#
# get_color
#
# Retrieves the color for a specific word, color is the most likely bucket
#
# $session  Session key returned by get_session_key
# $word     Word to get the color of
#
#----------------------------------------------------------------------------
sub get_color
{
    my ( $self, $session, $word ) = @_;

    my $max   = -10000;
    my $color = 'black';

    for my $bucket ($self->get_buckets( $session )) {
        my $prob = $self->get_value_( $session, $bucket, $word );

        if ( $prob != 0 )  {
            if ( $prob > $max )  {
                $max   = $prob;
                $color = $self->get_bucket_parameter( $session, $bucket, # PROFILE BLOCK START
                             'color' );                                  # PROFILE BLOCK STOP
            }
        }
    }

    return $color;
}

#----------------------------------------------------------------------------
#
# get_not_likely_
#
# Returns the probability of a word that doesn't appear
#
#----------------------------------------------------------------------------
sub get_not_likely_
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return $self->{not_likely__}{$userid};
}

#----------------------------------------------------------------------------
#
# get_value_
#
# Returns the value for a specific word in a bucket.  The word is
# converted to the log value of the probability before return to get
# the raw value just hit the hash directly or call get_base_value_
#
#----------------------------------------------------------------------------
sub get_value_
{
    my ( $self, $session, $bucket, $word ) = @_;

    my $value = $self->db_get_word_count__( $session, $bucket, $word );

    if ( defined( $value ) && ( $value > 0 ) ) {

        # Profiling notes:
        #
        # I tried caching the log of the total value and then doing
        # log( $value ) - $cached and this turned out to be
        # much slower than this single log with a division in it

        return log( $value /                                             # PROFILE BLOCK START
                    $self->get_bucket_word_count( $session, $bucket ) ); # PROFILE BLOCK STOP
    } else {
        return 0;
    }
}

sub get_base_value_
{
    my ( $self, $session, $bucket, $word ) = @_;

    my $value = $self->db_get_word_count__( $session, $bucket, $word );

    if ( defined( $value ) ) {
        return $value;
    } else {
        return 0;
    }
}

#----------------------------------------------------------------------------
#
# set_value_
#
# Sets the value for a word in a bucket and updates the total word
# counts for the bucket and globally
#
#----------------------------------------------------------------------------
sub set_value_
{
    my ( $self, $session, $bucket, $word, $value ) = @_;

    if ( $self->db_put_word_count__( $session, $bucket, # PROFILE BLOCK START
             $word, $value ) == 1 ) {                   # PROFILE BLOCK STOP

        # If we set the word count to zero then clean it up by deleting the
        # entry

        my $userid = $self->valid_session_key__( $session );
        my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
        $self->validate_sql_prepare_and_execute(          # PROFILE BLOCK START
            $self->{db_delete_zero_words__}, $bucketid ); # PROFILE BLOCK STOP

        return 1;
    } else {
        return 0;
    }
}

#----------------------------------------------------------------------------
#
# get_sort_value_ behaves the same as get_value_, except that it
# returns not_likely__ rather than 0 if the word is not found.  This
# makes its result more suitable as a sort key for bucket ranking.
#
#----------------------------------------------------------------------------
sub get_sort_value_
{
    my ( $self, $session, $bucket, $word ) = @_;

    my $v = $self->get_value_( $session, $bucket, $word );

    if ( $v == 0 ) {

        my $userid = $self->valid_session_key__( $session );
        return undef if ( !defined( $userid ) );

        return $self->{not_likely__}{$userid};
    } else {
        return $v;
    }
}

#----------------------------------------------------------------------------
#
# update_constants__
#
# Updates not_likely and bucket_start
#
#----------------------------------------------------------------------------
sub update_constants__
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $wc = $self->get_word_count( $session );

    if ( $wc > 0 )  {
        $self->{not_likely__}{$userid} = -log( 10 * $wc );

        foreach my $bucket ( $self->get_buckets( $session ) ) {
            my $total = $self->get_bucket_word_count( $session, $bucket );

            if ( $total != 0 ) {
                $self->{bucket_start__}{$userid}{$bucket} =  # PROFILE BLOCK START
                    log( $total / $wc );                     # PROFILE BLOCK STOP
            } else {
                $self->{bucket_start__}{$userid}{$bucket} = 0;
            }
        }
    } else {
        $self->{not_likely__}{$userid} = 0;
    }
}

#----------------------------------------------------------------------------
#
# db_connect__
#
# Connects to the POPFile database and returns 1 if successful
#
#----------------------------------------------------------------------------
sub db_connect__
{
    my ( $self ) = @_;

    # Connect to the database, note that the database must exist for
    # this to work, to make this easy for people POPFile we will
    # create the database automatically here using the file
    # 'popfile.sql' which should be located in the same directory the
    # Classifier/Bayes.pm module

    # If we are using SQLite then the dbname is actually the name of a
    # file, and hence we treat it like one, otherwise we leave it
    # alone

    my $dbname;
    my $dbconnect = $self->config_( 'dbconnect' );
    my $dbpresent;
    my $sqlite = ( $dbconnect =~ /sqlite/i );
    my $mysql  = ( $dbconnect =~ /mysql/i );
    my %connection_options = ();

    if ( $sqlite ) {
        $dbname = $self->get_user_path_( $self->config_( 'database' ) );
        $dbpresent = ( -e $dbname ) || 0;
    } else {
        $dbname = $self->config_( 'database' );
        $dbpresent = 1;

        if ( $mysql ) {

            # Turn on auto_reconnect

            $connection_options{mysql_auto_reconnect} = 1;
        }
    }

    # Record whether we are using SQLite or not and the name of the
    # database so that other routines can access it; this is used by
    # the backup_database__ routine to make a backup copy of the
    # database when using SQLite.

    $self->{db_is_sqlite__} = $sqlite;
    $self->{db_name__}      = $dbname;

    # Now perform the connect, note that this is database independent
    # at this point, the actual database that we connect to is defined
    # by the dbconnect parameter.

    $dbconnect =~ s/\$dbname/$dbname/g;

    $self->log_( 0, "Attempting to connect to $dbconnect ($dbpresent)" );

    my $need_convert = 0;
    my $old_dbh;

    if ( $sqlite && $dbpresent ) {

        # Check if the database is SQLite2 format

        open DBFILE, $dbname;
        my $buffer;
        my $readed = sysread( DBFILE, $buffer, 47 );
        close DBFILE;

        if ( $buffer eq '** This file contains an SQLite 2.1 database **' ) {
            $self->log_( 0, 'SQLite 2 database found. Try to upgrade' );

            # Test DBD::SQLite version

            my $ver = -1;
            eval {
                require DBD::SQLite;
                $ver = $DBD::SQLite::VERSION;
            };

            if ( $ver ge '1.00' ) {
                $self->log_( 0, "DBD::SQLite $ver found" );

                # Backup SQLite2 database

                my $old_dbname = $dbname . '-sqlite2';
                unlink $old_dbname;
                rename $dbname, $old_dbname;

                # Connect to SQLite2 database

                my $old_dbconnect = $self->config_( 'dbconnect' );
                $old_dbconnect =~ s/SQLite:/SQLite2:/;
                $old_dbconnect =~ s/\$dbname/$old_dbname/g;

                $old_dbh = DBI->connect( $old_dbconnect,               # PROFILE BLOCK START
                                         $self->config_( 'dbuser' ),
                                         $self->config_( 'dbauth' ) ); # PROFILE BLOCK STOP

                # Update the config file

                $dbconnect = $self->config_( 'dbconnect' );
                $dbconnect =~ s/SQLite2:/SQLite:/;
                $self->config_( 'dbconnect', $dbconnect );
                $dbconnect =~ s/\$dbname/$dbname/g;

                $need_convert = 1;
            }
        } else {

            # Update the config file

            $dbconnect = $self->config_( 'dbconnect' );
            $dbconnect =~ s/SQLite2:/SQLite:/;
            $self->config_( 'dbconnect', $dbconnect );
            $dbconnect =~ s/\$dbname/$dbname/g;
        }
    }

    if ( $sqlite && ( $^O eq 'MSWin32' ) &&               # PROFILE BLOCK START
         ( $self->{parser__}->{lang__} eq 'Nihongo' ) &&
         ( $dbconnect =~ /SQLite:/ ) ) {                  # PROFILE BLOCK STOP

        require DBD::SQLite;

        if ( ( $DBD::SQLite::VERSION ge '1.10' ) ||          # PROFILE BLOCK START
             ( $DBD::SQLite::sqlite_version ge '3.2.6' ) ) { # PROFILE BLOCK STOP

            # SQLite 3.2.6 or later uses the unicode API in Windows.
            # http://www.sqlite.org/changes.html#version_3_2_6

            # We need to convert database path to UTF-8 if we are using
            # SQLite 3.2.6 or later.

            require File::Glob::Windows;
            require Encode;

            my $code_page = File::Glob::Windows::getCodePage();

            $self->log_( 1, "Converting database connection string from $code_page to utf-8." );

            Encode::from_to( $dbconnect, $code_page, 'utf-8' );
        }
    }

    $self->{db__} = DBI->connect( $dbconnect,                 # PROFILE BLOCK START
                                  $self->config_( 'dbuser' ),
                                  $self->config_( 'dbauth' ),
                                  \%connection_options );     # PROFILE BLOCK STOP

    if ( !defined( $self->{db__} ) ) {
        $self->log_( 0, "Failed to connect to database and got error $DBI::errstr" );
        return 0;
    }

    if ( $sqlite ) {
        $self->log_( 0, "Using SQLite library version " . $self->{db__}{sqlite_version} );

        if ( $need_convert ) {
            $self->log_( 0, 'Convert SQLite2 database to SQLite3 database' );

            $self->db_upgrade__( $old_dbh );
            $old_dbh->disconnect;

            $self->log_( 0, 'Database convert completed' );
        }

        # Set the synchronous mode to normal ( default of SQLite 2.x ).

        $self->tweak_sqlite( 1, 1, $self->{db__} );

        # For Japanese compatibility

        if ( $self->{parser__}->{lang__} eq 'Nihongo' ) {
            $self->{db__}->do( 'pragma case_sensitive_like=1;' );
        }

        if ( $self->{db__}{sqlite_version} ge '3.6.0' ) {
            # Configure journal mode

            my $journal_mode = $self->config_( 'sqlite_journal_mode' );

            if ( $journal_mode =~ /^(delete|truncate|persist|memory|off)$/i ) {
                $self->{db__}->do( "pragma journal_mode=$journal_mode;" );
            }
        }
    }

    if ( !$dbpresent ) {
        if ( !$self->insert_schema__( $sqlite ) ) {
            return 0;
        }
    }

    # Now check for a need to upgrade the database because the schema
    # has been changed.  From POPFile v0.22.0 there's a special
    # 'popfile' table inside the database that contains the schema
    # version number.  If the version number doesn't match or is
    # missing then do the upgrade.

    open SCHEMA, '<' . $self->get_root_path_( 'Classifier/popfile.sql' );
    <SCHEMA> =~ /-- POPFILE SCHEMA (\d+)/;
    my $version = $1;
    close SCHEMA;

    my $need_upgrade = 1;

    #
    # retrieve the SQL_IDENTIFIER_QUOTE_CHAR for the database then use it
    # to strip off any sqlquotechars from the table names we retrieve
    #

    my $sqlquotechar = $self->{db__}->get_info(29) || '';
    my @tables = map { s/$sqlquotechar//g; $_ } ($self->{db__}->tables());

    foreach my $table (@tables) {
        if ( $table =~ /\.?popfile$/ ) {
            my @row = $self->{db__}->selectrow_array(  # PROFILE BLOCK START
               'select version from popfile;' );       # PROFILE BLOCK STOP

            if ( $#row == 0 ) {
                $need_upgrade = ( $row[0] != $version );
            }
        }
    }

    if ( $need_upgrade ) {

        print "\n\nDatabase schema is outdated, performing automatic upgrade\n";

        # The database needs upgrading

        $self->db_upgrade__();

        print "\nDatabase upgrade complete\n\n";
    }

    # Now prepare common SQL statements for use, as a matter of convention the
    # parameters to each statement always appear in the following order:
    #
    # user
    # bucket
    # word
    # parameter

    $self->{db_get_buckets__} = $self->{db__}->prepare(                                 # PROFILE BLOCK START
             'select name, id, pseudo from buckets
                  where buckets.userid = ?;' );                                         # PROFILE BLOCK STOP

    $self->{db_get_wordid__} = $self->{db__}->prepare(                                  # PROFILE BLOCK START
             'select id from words
                  where words.word = ? limit 1;' );                                     # PROFILE BLOCK STOP

    $self->{db_get_userid__} = $self->{db__}->prepare(                                  # PROFILE BLOCK START
             'select id from users where name = ?
                                     and password = ? limit 1;' );                      # PROFILE BLOCK STOP

    $self->{db_get_word_count__} = $self->{db__}->prepare(                              # PROFILE BLOCK START
             'select matrix.times from matrix
                  where matrix.bucketid = ? and
                        matrix.wordid = ? limit 1;' );                                  # PROFILE BLOCK STOP

    $self->{db_put_word_count__} = $self->{db__}->prepare(                              # PROFILE BLOCK START
           'replace into matrix ( bucketid, wordid, times ) values ( ?, ?, ? );' );     # PROFILE BLOCK STOP

    $self->{db_get_bucket_word_counts__} = $self->{db__}->prepare(                      # PROFILE BLOCK START
             'select sum(matrix.times), count(matrix.id), buckets.name from matrix, buckets
                  where matrix.bucketid = buckets.id
                    and buckets.userid = ?
                    group by buckets.name;' );                                          # PROFILE BLOCK STOP

    $self->{db_get_bucket_word_count__} = $self->{db__}->prepare(                       # PROFILE BLOCK START
             'select sum(times), count(*) from matrix
                  where bucketid = ?' );                                                # PROFILE BLOCK STOP

    $self->{db_get_unique_word_count__} = $self->{db__}->prepare(                       # PROFILE BLOCK START
             'select count(*) from matrix
                  where matrix.bucketid in (
                        select buckets.id from buckets
                            where buckets.userid = ? );' );                             # PROFILE BLOCK STOP

    $self->{db_get_full_total__} = $self->{db__}->prepare(                              # PROFILE BLOCK START
             'select sum(matrix.times) from matrix
                  where matrix.bucketid in (
                        select buckets.id from buckets
                            where buckets.userid = ? );' );                             # PROFILE BLOCK STOP

    $self->{db_get_bucket_parameter__} = $self->{db__}->prepare(                        # PROFILE BLOCK START
             'select bucket_params.val from bucket_params
                  where bucket_params.bucketid = ? and
                        bucket_params.btid = ?;' );                                     # PROFILE BLOCK STOP

    $self->{db_set_bucket_parameter__} = $self->{db__}->prepare(                        # PROFILE BLOCK START
           'replace into bucket_params ( bucketid, btid, val ) values ( ?, ?, ? );' );  # PROFILE BLOCK STOP

    $self->{db_get_bucket_parameter_default__} = $self->{db__}->prepare(                # PROFILE BLOCK START
             'select bucket_template.def from bucket_template
                  where bucket_template.id = ?;' );                                     # PROFILE BLOCK STOP

    $self->{db_get_buckets_with_magnets__} = $self->{db__}->prepare(                    # PROFILE BLOCK START
             'select buckets.name from buckets, magnets
                  where buckets.userid = ? and
                        magnets.id != 0 and
                        magnets.bucketid = buckets.id group by buckets.name order by buckets.name;' );
                                                                                        # PROFILE BLOCK STOP
    $self->{db_delete_zero_words__} = $self->{db__}->prepare(                           # PROFILE BLOCK START
             'delete from matrix
                  where matrix.times = 0
                    and matrix.bucketid = ?;' );                                        # PROFILE BLOCK STOP

    # Get the mapping from parameter names to ids into a local hash

    my $h = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select name, id from bucket_template;' );    # PROFILE BLOCK STOP
    while ( my $row = $h->fetchrow_arrayref ) {
        $self->{db_parameterid__}{$row->[0]} = $row->[1];
    }
    $h->finish;

    return 1;
}

#----------------------------------------------------------------------------
#
# insert_schema__
#
# Insert the POPFile schema in a database
#
# $sqlite          Set to 1 if this is a SQLite database
#
#----------------------------------------------------------------------------
sub insert_schema__
{
    my ( $self, $sqlite ) = @_;

    if ( -e $self->get_root_path_( 'Classifier/popfile.sql' ) ) {
        my $schema = '';

        $self->log_( 0, "Creating database schema" );

        open SCHEMA, '<' . $self->get_root_path_( 'Classifier/popfile.sql' );
        while ( <SCHEMA> ) {
            next if ( /^--/ );
            next if ( !/[a-z;]/ );
            s/--.*$//;

            # If the line begins 'alter' and we are doing SQLite then ignore
            # the line

            if ( $sqlite && ( /^alter/i ) ) {
                next;
            }

            $schema .= $_;

            if ( ( /end;/ ) || ( /\);/ ) || ( /^alter/i ) ) {
                $self->{db__}->do( $schema );
                $schema = '';
            }
        }
        close SCHEMA;
        return 1;
    } else {
        $self->log_( 0, "Can't find the database schema" );
        return 0;
    }
}

#----------------------------------------------------------------------------
#
# db_upgrade__
#
# Upgrade the POPFile schema / Convert the database
#
# $db_from         Database handle convert from
#                  undef if upgrade POPFile schema
#
#----------------------------------------------------------------------------
sub db_upgrade__
{
    my ( $self, $db_from ) = @_;

    my $drop_table;

    if ( !defined( $db_from ) ) {
        # Upgrade

        $drop_table = 1;
        $db_from = $self->{db__};
    }

    my $from_sqlite = ( $db_from->{Driver}->{Name} =~ /SQLite/ );
    my $to_sqlite = ( $self->{db__}->{Driver}->{Name} =~ /SQLite/ );

    my $sqlquotechar = $db_from->get_info(29) || '';
    my @tables = map { s/$sqlquotechar//g; $_ } ($db_from->tables());

    # We are going to dump out all the data in the database as
    # INSERT OR IGNORE statements in a temporary file, then DROP all
    # the tables in the database, then recreate the schema from the
    # new schema and finally rerun the inserts.

    my $i = 0;
    my $ins_file = $self->get_user_path_( 'insert.sql' );
    open INSERT, '>' . $ins_file;

    foreach my $table (@tables) {
        next if ( $table =~ /\.?popfile$/ );
        if ( $from_sqlite && ( $table =~ /^sqlite_/ ) ) {
            next;
        }
        if ( $i > 99 ) {
            print "\n";
        }
        print "    Saving table $table\n    ";

        my $t = $db_from->prepare( "select * from $table;" );
        $t->execute;
        $i = 0;
        while ( 1 ) {
            if ( ( ++$i % 100 ) == 0 ) {
                print "[$i]";
                flush STDOUT;
            }
            if ( ( $i % 1000 ) == 0 ) {
                print "\n";
                flush STDOUT;
            }
            my $rows = $t->fetchrow_arrayref;

            last if ( !defined( $rows ) );

            if ( $to_sqlite ) {
                print INSERT "INSERT OR IGNORE INTO $table (";
            } else {
                print INSERT "INSERT INTO $table (";
            }
            for my $i (0..$t->{NUM_OF_FIELDS}-1) {
                if ( $i != 0 ) {
                    print INSERT ',';
                }
                print INSERT $t->{NAME}->[$i];
            }
            print INSERT ') VALUES (';
            for my $i (0..$t->{NUM_OF_FIELDS}-1) {
                if ( $i != 0 ) {
                    print INSERT ',';
                }
                my $val = $rows->[$i];
                if ( $t->{TYPE}->[$i] !~ /^int/i ) {
                    $val = '' if ( !defined( $val ) );
                    $val = $self->db_quote( $val );
                } else {
                    $val = 'NULL' if ( !defined( $val ) );
                }
                print INSERT $val;
            }
            print INSERT ");\n";
        }
        $t->finish;
    }

    close INSERT;

    if ( $i > 99 ) {
        print "\n";
    }

    if ( $drop_table ) {
        foreach my $table (@tables) {
            if ( $from_sqlite && ( $table =~ /^sqlite_/ ) ) {
                next;
            }
            print "    Dropping old table $table\n";
            $self->{db__}->do( "DROP TABLE $table;" );
        }
    }

    print "    Inserting new database schema\n";
    if ( !$self->insert_schema__( $to_sqlite ) ) {
        return 0;
    }

    print "    Restoring old data\n    ";

    $self->{db__}->begin_work;
    open INSERT, '<' . $ins_file;
    $i = 0;
    while ( <INSERT> ) {
        if ( ( ++$i % 100 ) == 0 ) {
           print "[$i]";
           flush STDOUT;
        }
        if ( ( $i % 1000 ) == 0 ) {
            print "\n";
            flush STDOUT;
        }
        s/[\r\n]//g;
        $self->{db__}->do( $_ );
    }
    close INSERT;
    $self->{db__}->commit;

    unlink $ins_file;
}

#----------------------------------------------------------------------------
#
# db_disconnect__
#
# Disconnect from the POPFile database
#
#----------------------------------------------------------------------------
sub db_disconnect__
{
    my ( $self ) = @_;

    $self->{db_get_buckets__}->finish;
    $self->{db_get_wordid__}->finish;
    $self->{db_get_userid__}->finish;
    $self->{db_get_word_count__}->finish;
    $self->{db_put_word_count__}->finish;
    $self->{db_get_bucket_word_counts__}->finish;
    $self->{db_get_bucket_word_count__}->finish;
    $self->{db_get_unique_word_count__}->finish;
    $self->{db_get_full_total__}->finish;
    $self->{db_get_bucket_parameter__}->finish;
    $self->{db_set_bucket_parameter__}->finish;
    $self->{db_get_bucket_parameter_default__}->finish;
    $self->{db_get_buckets_with_magnets__}->finish;
    $self->{db_delete_zero_words__}->finish;

    # Avoid DBD::SQLite 'closing dbh with active statement handles' bug

    undef $self->{db_get_buckets__};
    undef $self->{db_get_wordid__};
    undef $self->{db_get_userid__};
    undef $self->{db_get_word_count__};
    undef $self->{db_put_word_count__};
    undef $self->{db_get_bucket_word_counts__};
    undef $self->{db_get_bucket_word_count__};
    undef $self->{db_get_unique_word_count__};
    undef $self->{db_get_full_total__};
    undef $self->{db_get_bucket_parameter__};
    undef $self->{db_set_bucket_parameter__};
    undef $self->{db_get_bucket_parameter_default__};
    undef $self->{db_get_buckets_with_magnets__};
    undef $self->{db_delete_zero_words__};

    if ( defined( $self->{db__} ) ) {
        $self->{db__}->disconnect;
        undef $self->{db__};
    }
}

#----------------------------------------------------------------------------
#
# db_update_cache__
#
# Updates our local cache of user and bucket ids.
#
# $session           Must be a valid session
# $updated_bucket    Bucket to update cache
# $deleted_bucket    Bucket to delete cache
#                    If none of them is specified, update whole cache.
#
#----------------------------------------------------------------------------
sub db_update_cache__
{
    my ( $self, $session, $updated_bucket, $deleted_bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    delete $self->{db_bucketid__}{$userid};

    $self->validate_sql_prepare_and_execute( $self->{db_get_buckets__}, $userid );
    while ( my $row = $self->{db_get_buckets__}->fetchrow_arrayref ) {
        $self->{db_bucketid__}{$userid}{$row->[0]}{id} = $row->[1];
        $self->{db_bucketid__}{$userid}{$row->[0]}{pseudo} = $row->[2];
    }

    my $updated = 0;

    if ( defined( $updated_bucket ) &&                                    # PROFILE BLOCK START
         defined( $self->{db_bucketid__}{$userid}{$updated_bucket} ) ) {  # PROFILE BLOCK STOP

        # Update cache for specified bucket.

        my $bucketid = $self->{db_bucketid__}{$userid}{$updated_bucket}{id};
        $self->validate_sql_prepare_and_execute(              # PROFILE BLOCK START
            $self->{db_get_bucket_word_count__}, $bucketid ); # PROFILE BLOCK STOP
        my $row = $self->{db_get_bucket_word_count__}->fetchrow_arrayref;

        $self->{db_bucketcount__}{$userid}{$updated_bucket} =  # PROFILE BLOCK START
            ( defined( $row->[0] ) ? $row->[0] : 0 );          # PROFILE BLOCK STOP
        $self->{db_bucketunique__}{$userid}{$updated_bucket} = $row->[1];

        $updated = 1;
    }

    if ( defined( $deleted_bucket ) &&                                     # PROFILE BLOCK START
         !defined( $self->{db_bucketid__}{$userid}{$deleted_bucket} ) ) {  # PROFILE BLOCK STOP

        # Delete cache for specified bucket.

        delete $self->{db_bucketcount__}{$userid}{$deleted_bucket};
        delete $self->{db_bucketunique__}{$userid}{$deleted_bucket};

        $updated = 1;
    }

    if ( !$updated ) {
        delete $self->{db_bucketcount__}{$userid};
        delete $self->{db_bucketunique__}{$userid};

        $self->validate_sql_prepare_and_execute(             # PROFILE BLOCK START
            $self->{db_get_bucket_word_counts__}, $userid ); # PROFILE BLOCK STOP

        for my $b (sort keys %{$self->{db_bucketid__}{$userid}}) {
            $self->{db_bucketcount__}{$userid}{$b} = 0;
            $self->{db_bucketunique__}{$userid}{$b} = 0;
        }

        while ( my $row = $self->{db_get_bucket_word_counts__}->fetchrow_arrayref ) {
            $self->{db_bucketcount__}{$userid}{$row->[2]} = $row->[0];
            $self->{db_bucketunique__}{$userid}{$row->[2]} = $row->[1];
        }
    }

    $self->update_constants__( $session );
}

#----------------------------------------------------------------------------
#
# db_get_word_count__
#
# Return the 'count' value for a word in a bucket.  If the word is not
# found in that bucket then returns undef.
#
# $session          Valid session ID from get_session_key
# $bucket           bucket word is in
# $word             word to lookup
#
#----------------------------------------------------------------------------
sub db_get_word_count__
{
    my ( $self, $session, $bucket, $word ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        $self->{db_get_wordid__}, $word );    # PROFILE BLOCK STOP
    my $result = $self->{db_get_wordid__}->fetchrow_arrayref;
    if ( !defined( $result ) ) {
        return undef;
    }

    my $wordid = $result->[0];

    $self->validate_sql_prepare_and_execute(                     # PROFILE BLOCK START
        $self->{db_get_word_count__},
        $self->{db_bucketid__}{$userid}{$bucket}{id}, $wordid ); # PROFILE BLOCK STOP
    $result = $self->{db_get_word_count__}->fetchrow_arrayref;
    if ( defined( $result ) ) {
         return $result->[0];
    } else {
         return undef;
    }
}

#----------------------------------------------------------------------------
#
# db_put_word_count__
#
# Update 'count' value for a word in a bucket, if the update fails
# then returns 0 otherwise is returns 1
#
# $session          Valid session ID from get_session_key
# $bucket           bucket word is in
# $word             word to update
# $count            new count value
#
#----------------------------------------------------------------------------
sub db_put_word_count__
{
    my ( $self, $session, $bucket, $word, $count ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # We need to have two things before we can start, the id of the
    # word in the words table (if there's none then we need to add the
    # word), the bucket id in the buckets table (which must exist)

    my $result = $self->validate_sql_prepare_and_execute(         # PROFILE BLOCK START
            $self->{db_get_wordid__}, $word )->fetchrow_arrayref; # PROFILE BLOCK STOP

    if ( !defined( $result ) ) {
        $self->validate_sql_prepare_and_execute(                     # PROFILE BLOCK START
                'insert into words ( word ) values ( ? );', $word ); # PROFILE BLOCK STOP
        $result = $self->validate_sql_prepare_and_execute(            # PROFILE BLOCK START
                $self->{db_get_wordid__}, $word )->fetchrow_arrayref; # PROFILE BLOCK STOP
    }

    my $wordid = $result->[0];
    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};

    $self->validate_sql_prepare_and_execute(                            # PROFILE BLOCK START
            $self->{db_put_word_count__}, $bucketid, $wordid, $count ); # PROFILE BLOCK STOP

    return 1;
}

#----------------------------------------------------------------------------
#
# upgrade_predatabase_data__
#
# Looks for old POPFile data (in flat files or BerkeleyDB tables) and
# upgrades it to the SQL database.  Data upgraded is removed.
#
#----------------------------------------------------------------------------
sub upgrade_predatabase_data__
{
    my ( $self ) = @_;
    my $c      = 0;

    # There's an assumption here that this is the single user version
    # of POPFile and hence what we do is cheat and get a session key
    # assuming that the user name is admin with password ''

    my $session = $self->get_session_key( 'admin', '' );

    if ( !defined( $session ) ) {
        $self->log_( 0, "Tried to get the session key for user admin and failed; cannot upgrade old data" );
        return;
    }

    my @buckets = glob $self->get_user_path_( $self->config_( 'corpus' ) . '/*' );

    foreach my $bucket (@buckets) {

        # A bucket directory must be a directory

        next unless ( -d $bucket );
        next unless ( ( -e "$bucket/table" ) || ( -e "$bucket/table.db" ) );

        return 0 if ( !$self->upgrade_bucket__( $session, $bucket ) );

        my $color = '';

        # See if there's a color file specified
        if ( open COLOR, '<' . "$bucket/color" ) {
            $color = <COLOR>;

            # Someone (who shall remain nameless) went in and manually created
            # empty color files in their corpus directories which would cause
            # $color at this point to be undefined and hence you'd get warnings
            # about undefined variables below.  So this little test is to deal
            # with that user and to make POPFile a little safer which is always
            # a good thing

            if ( !defined( $color ) ) {
                $color = '';
            } else {
                $color =~ s/[\r\n]//g;
            }
            close COLOR;
            unlink "$bucket/color";
        }

        $bucket =~ /([[:alpha:]0-9-_]+)$/;
        $bucket =  $1;

        $self->set_bucket_color( $session, $bucket, ($color eq '')?$self->{possible_colors__}[$c]:$color );

        $c = ($c+1) % ($#{$self->{possible_colors__}}+1);
    }

    $self->release_session_key( $session );

    return 1;
}

#----------------------------------------------------------------------------
#
# upgrade_bucket__
#
# Loads an individual bucket
#
# $session           Valid session key from get_session_key
# $bucket            The bucket name
#
#----------------------------------------------------------------------------
sub upgrade_bucket__
{
    my ( $self, $session, $bucket ) = @_;

    $bucket =~ /([[:alpha:]0-9-_]+)$/;
    $bucket =  $1;

    $self->create_bucket( $session, $bucket );

    if ( open PARAMS, '<' . $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/params" ) ) {
        while ( <PARAMS> )  {
            s/[\r\n]//g;
            if ( /^([[:lower:]]+) ([^\r\n\t ]+)$/ )  {
                $self->set_bucket_parameter( $session, $bucket, $1, $2 );
            }
        }
        close PARAMS;
        unlink $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/params" );
    }

    # Pre v0.21.0 POPFile had GLOBAL parameters for subject modification,
    # XTC and XPL insertion.  To make the upgrade as clean as possible
    # check these parameters so that if they were OFF we set the equivalent
    # per bucket to off

    foreach my $gl ( 'subject', 'xtc', 'xpl' ) {
        $self->log_( 1, "Checking deprecated parameter GLOBAL_$gl for $bucket\n" );
        my $val = $self->{configuration__}->deprecated_parameter( "GLOBAL_$gl" );
        if ( defined( $val ) && ( $val == 0 ) ) {
            $self->log_( 1, "GLOBAL_$gl is 0 for $bucket, overriding $gl\n" );
            $self->set_bucket_parameter( $session, $bucket, $gl, 0 );
        }
    }

    # See if there are magnets defined
    if ( open MAGNETS, '<' . $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/magnets" ) ) {
        while ( <MAGNETS> )  {
            s/[\r\n]//g;

            # Because of a bug in v0.17.9 and earlier of POPFile the text of
            # some magnets was getting mangled by certain characters having
            # a \ prepended.  Code here removes the \ in these cases to make
            # an upgrade smooth.

            if ( /^([^ ]+) (.+)$/ )  {
                my $type  = $1;
                my $value = $2;

                # Some people were accidently creating magnets with
                # trailing whitespace which really confused them later
                # when their magnet did not match (see comment in
                # UI::HTML::magnet for more detail)

                $value =~ s/^[ \t]+//g;
                $value =~ s/[ \t]+$//g;

                $value =~ s/\\(\?|\*|\||\(|\)|\[|\]|\{|\}|\^|\$|\.)/$1/g;
                $self->create_magnet( $session, $bucket, $type, $value );
            } else {

                # This branch is used to catch the original magnets in an
                # old version of POPFile that were just there for from
                # addresses only

                if ( /^(.+)$/ ) {
                    my $value = $1;
                    $value =~ s/\\(\?|\*|\||\(|\)|\[|\]|\{|\}|\^|\$|\.)/$1/g;
                    $self->create_magnet( $session, $bucket, 'from', $value );
                }
            }
        }
        close MAGNETS;
        unlink $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/magnets" );
    }

    # If there is no existing table but there is a table file (the old style
    # flat file used by POPFile for corpus storage) then create the new
    # database from it thus performing an automatic upgrade.

    if ( -e $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/table" ) ) {
        $self->log_( 0, "Performing automatic upgrade of $bucket corpus from flat file to DBI" );

        $self->{db__}->begin_work;

        if ( open WORDS, '<' . $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/table" ) )  {

            my $wc = 1;

            my $first = <WORDS>;
            if ( defined( $first ) && ( $first =~ s/^__CORPUS__ __VERSION__ (\d+)// ) ) {
                if ( $1 != $self->{corpus_version__} )  {
                    print STDERR "Incompatible corpus version in $bucket\n";
                    close WORDS;
                    $self->{db__}->rollback;
                    return 0;
                } else {
                    $self->log_( 0, "Upgrading bucket $bucket..." );

                    while ( <WORDS> ) {
                        if ( $wc % 100 == 0 ) {
                            $self->log_( 0, "$wc" );
                        }
                        $wc += 1;
                        s/[\r\n]//g;

                        if ( /^([^\s]+) (\d+)$/ ) {
                            if ( $2 != 0 ) {
                                $self->db_put_word_count__( $session, $bucket, $1, $2 );
                            }
                        } else {
                            $self->log_( 0, "Found entry in corpus for $bucket that looks wrong: \"$_\" (ignoring)" );
                        }
                    }
                }

                if ( $wc > 1 ) {
                    $wc -= 1;
                    $self->log_( 0, "(completed $wc words)" );
                }
                close WORDS;
            } else {
                close WORDS;
                $self->{db__}->rollback;
                unlink $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/table" );
                return 0;
            }

            $self->{db__}->commit;
            unlink $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/table" );
        }
    }

    # Now check to see if there's a BerkeleyDB-style table

    my $bdb_file = $self->get_user_path_( $self->config_( 'corpus' ) . "/$bucket/table.db" );

    if ( -e $bdb_file ) {
        $self->log_( 0, "Performing automatic upgrade of $bucket corpus from BerkeleyDB to DBI" );

        require BerkeleyDB;

        my %h;
        tie %h, "BerkeleyDB::Hash", -Filename => $bdb_file;

        $self->log_( 0, "Upgrading bucket $bucket..." );
        $self->{db__}->begin_work;

        my $wc = 1;

        for my $word (keys %h) {
            if ( $wc % 100 == 0 ) {
                $self->log_( 0, "$wc" );
            }

            next if ( $word =~ /__POPFILE__(LOG__TOTAL|TOTAL|UNIQUE)__/ );

            $wc += 1;
            if ( $h{$word} != 0 ) {
                $self->db_put_word_count__( $session, $bucket, $word, $h{$word} );
            }
        }

        $wc -= 1;
        $self->log_( 0, "(completed $wc words)" );
        $self->{db__}->commit;
        untie %h;
        unlink $bdb_file;
    }

    return 1;
}

#----------------------------------------------------------------------------
#
# magnet_match_helper__
#
# Helper the determines if a specific string matches a certain magnet
# type in a bucket, used by magnet_match_
#
# $session         Valid session from get_session_key
# $match           The string to match
# $bucket          The bucket to check
# $type            The magnet type to check
#
#----------------------------------------------------------------------------
sub magnet_match_helper__
{
    my ( $self, $session, $match, $bucket, $type ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @magnets;

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $h = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnets.val, magnets.id from magnets, users, buckets, magnet_types
                where buckets.id         = ? and
                      magnets.id        != 0 and
                      users.id           = buckets.userid and
                      magnets.bucketid   = buckets.id and
                      magnet_types.mtype = ? and
                      magnets.mtid       = magnet_types.id
                order by magnets.val;',
        $bucketid, $type );                           # PROFILE BLOCK STOP

    my ( $val, $id );
    $h->bind_columns( \$val, \$id );
    while ( my $row = $h->fetchrow_arrayref ) {
        push @magnets, [ $val, $id ];
    }
    $h->finish;

    foreach my $m (@magnets) {
        my ( $magnet, $id ) = @{$m};

        if ( $self->single_magnet_match( $magnet, $match, $type ) ) {
            $self->{magnet_used__}   = 1;
            $self->{magnet_detail__} = $id;

            return 1;
        }
    }

    return 0;
}

#----------------------------------------------------------------------------
#
# single_magnet_match
#
# Helper the determines if a specific string matches a specific magnet
#
# $magnet          The magnet string
# $match           The string to match
# $type            The magnet type to check
#
#----------------------------------------------------------------------------
sub single_magnet_match {
    my ( $self, $magnet, $match, $type ) = @_;
    my $matched = 0;

    if ( $type =~ /^(from|to)$/ ) {
        # From / To
        if ( $magnet =~ /[\w]+\@[\w]+/ ) {
            # e-mail address -> exact match
            $matched = 1 if ( $match =~ m/(^|[^\w\-])\Q$magnet\E($|[^\w\.])/i );
        } elsif ( $magnet =~ /\./ ) {
            # domain name -> domain match
            if ( $magnet =~ /^[\@\.]/ ) {
                $matched = 1 if ( $match =~ /\Q$magnet\E($|[^\w\.])/i );
            } else {
                $matched = 1 if ( $match =~ m/[\@\.]\Q$magnet\E($|[^\w\.])/i );
            }
        } else {
            # name -> word match
            $matched = 1 if ( $match =~ m/(^|[^\w])\Q$magnet\E($|[^\w])/i );
        }
    } else {
        # Subject -> word match
        $matched = 1 if ( $match =~ m/(^|[^\w])\Q$magnet\E($|[^\w])/i );
    }

    return $matched;
}

#----------------------------------------------------------------------------
#
# magnet_match__
#
# Helper the determines if a specific string matches a certain magnet
# type in a bucket
#
# $session         Valid session from get_session_key
# $match           The string to match
# $bucket          The bucket to check
# $type            The magnet type to check
#
#----------------------------------------------------------------------------
sub magnet_match__
{
    my ( $self, $session, $match, $bucket, $type ) = @_;

    return $self->magnet_match_helper__( $session, $match, $bucket, $type );
}

#----------------------------------------------------------------------------
#
# write_line__
#
# Writes a line to a file and parses it unless the classification is
# already known
#
# $file         File handle for file to write line to
# $line         The line to write
# $class        (optional) The current classification
#
#----------------------------------------------------------------------------
sub write_line__
{
    my ( $self, $file, $line, $class ) = @_;

    if ( defined( $file ) && ( ref $file eq 'GLOB' ) ) {
        if ( defined( fileno $file ) ) {
            print $file $line;
        } else {
            my ( $package, $filename, $line, $subroutine ) = caller;
            $self->log_( 0, "Tried to write to a closed file. Called from $package line $line" );
        }
    }

    if ( $class eq '' ) {
        $self->{parser__}->parse_line( $line );
    }
}

#----------------------------------------------------------------------------
#
# add_words_to_bucket__
#
# Takes words previously parsed by the mail parser and adds/subtracts
# them to/from a bucket, this is a helper used by
# add_messages_to_bucket, remove_message_from_bucket
#
# $session        Valid session from get_session_key
# $bucket         Bucket to add to
# $subtract       Set to -1 means subtract the words, set to 1 means add
#
#----------------------------------------------------------------------------
sub add_words_to_bucket__
{
    my ( $self, $session, $bucket, $subtract ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Map the list of words to a list of counts currently in the database
    # then update those counts and write them back to the database.

    my $words;
    $words = join( ',', map( $self->{db__}->quote( $_ ), (sort keys %{$self->{parser__}{words__}}) ) );
    $self->{get_wordids__} = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
             "select id, word from words
                     where word in ( $words );" );                     # PROFILE BLOCK STOP

    my @id_list;
    my %wordmap;
    my ( $wordid, $word );

    $self->{get_wordids__}->bind_columns( \$wordid, \$word );
    while ( $self->{get_wordids__}->fetchrow_arrayref ) {
        push @id_list, $wordid;
        $wordmap{$word} = $wordid;
    }

    $self->{get_wordids__}->finish;
    undef $self->{get_wordids__};

    my $ids = join( ',', @id_list );

    $self->{db_getwords__} = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
            "select matrix.times, matrix.wordid from matrix
                    where matrix.wordid in ( $ids ) and
                          matrix.bucketid = ?;",
            $self->{db_bucketid__}{$userid}{$bucket}{id} );            # PROFILE BLOCK STOP

    my %counts;
    my $count;

    $self->{db_getwords__}->bind_columns( \$count, \$wordid );
    while ( $self->{db_getwords__}->fetchrow_arrayref ) {
        $counts{$wordid} = $count;
    }

    $self->{db_getwords__}->finish;
    undef $self->{db_getwords__};

    $self->{db__}->begin_work;
    foreach my $word (keys %{$self->{parser__}->{words__}}) {

        # If there's already a count then it means that the word is
        # already in the database and we have its id in
        # $wordmap{$word} so for speed we execute the
        # db_put_word_count__ query here rather than going through
        # set_value_ which would need to look up the wordid again

        if ( defined( $wordmap{$word} ) && defined( $counts{$wordmap{$word}} ) ) {
            $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
                $self->{db_put_word_count__},
                $self->{db_bucketid__}{$userid}{$bucket}{id},
                $wordmap{$word},
                $counts{$wordmap{$word}} +
                    $subtract * $self->{parser__}->{words__}{$word} ); # PROFILE BLOCK STOP
        } else {

            # If the word is not in the database and we are trying to
            # subtract then we do nothing because negative values are
            # meaningless

            if ( $subtract == 1 ) {
                $self->db_put_word_count__( $session, $bucket, $word, $self->{parser__}->{words__}{$word} );
            }
        }
    }

    # If we were doing a subtract operation it's possible that some of
    # the words in the bucket now have a zero count and should be
    # removed

    if ( $subtract == -1 ) {
        $self->validate_sql_prepare_and_execute(            # PROFILE BLOCK START
            $self->{db_delete_zero_words__},
            $self->{db_bucketid__}{$userid}{$bucket}{id} ); # PROFILE BLOCK STOP
    }

    $self->{db__}->commit;
}

#----------------------------------------------------------------------------
#
# echo_to_dot_
#
# $mail The stream (created with IO::) to send the message to (the
# remote mail server)
# $client (optional) The local mail client (created with IO::) that
# needs the response
# $file (optional) A file to print the response to, caller specifies
# open style
# $before (optional) String to send to client before the dot is sent
#
# echo all information from the $mail server until a single line with
# a . is seen
#
# NOTE Also echoes the line with . to $client but not to $file
#
# Returns 1 if there was a . or 0 if reached EOF before we hit the .
#
#----------------------------------------------------------------------------
sub echo_to_dot_
{
    my ( $self, $mail, $client, $file, $before ) = @_;

    my $hit_dot = 0;

    my $isopen = open FILE, "$file" if ( defined( $file ) );
    binmode FILE if ($isopen);

    while ( my $line = $self->slurp_( $mail ) ) {

        # Check for an abort

        last if ( $self->{alive_} == 0 );

        # The termination has to be a single line with exactly a dot
        # on it and nothing else other than line termination
        # characters.  This is vital so that we do not mistake a line
        # beginning with . as the end of the block

        if ( $line =~ /^\.(\r\n|\r|\n)$/ ) {
            $hit_dot = 1;

            if ( defined( $before ) && ( $before ne '' ) ) {
                print $client $before if ( defined( $client ) );
                print FILE    $before if ( defined( $isopen ) );
            }

            # Note that there is no print FILE here.  This is correct
            # because we do no want the network terminator . to appear
            # in the file version of any message

            print $client $line if ( defined( $client ) );
            last;
        }

        print $client $line if ( defined( $client ) );
        print FILE    $line if ( defined( $isopen ) );

    }

    close FILE if ( $isopen );

    return $hit_dot;
}

#----------------------------------------------------------------------------
#
# substr_euc__
#
# "substr" function which supports EUC Japanese charset
#
# $pos      Start position
# $len      Word length
#
#----------------------------------------------------------------------------
sub substr_euc__
{
    my ( $str, $pos, $len ) = @_;
    my $result_str;
    my $char;
    my $count = 0;
    if ( !$pos ) {
        $pos = 0;
    }
    if ( !$len ) {
        $len = length( $str );
    }

    for ( $pos = 0; $count < $len; $pos++ ) {
        $char = substr( $str, $pos, 1 );
        if ( $char =~ /[\x80-\xff]/ ) {
            $char = substr( $str, $pos++, 2 );
        }
        $result_str .= $char;
        $count++;
    }

    return $result_str;
}

#----------------------------------------------------------------------------
#
# generate_unique_session_key__
#
# Returns a unique string based session key that can be used as a key
# in the api_sessions__
#
#----------------------------------------------------------------------------
sub generate_unique_session_key__
{
    my ( $self ) = @_;

    my @chars = ( 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',   # PROFILE BLOCK START
                  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'U', 'V', 'W', 'X', 'Y',
                  'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A' ); # PROFILE BLOCK STOP

    my $session;

    do {
        $session = '';
        my $length = int( 16 + rand(4) );

        for my $i (0 .. $length) {
            my $random = $chars[int( rand(36) )];

            # Just to add spice to things we sometimes lowercase the value

            if ( rand(1) < rand(1) ) {
                $random = lc($random);
            }

            $session .= $random;
        }
    } while ( defined( $self->{api_sessions__}{$session} ) );

    return $session;
}

#----------------------------------------------------------------------------
#
# release_session_key_private__
#
# $session        A session key previously returned by get_session_key
#
# Releases and invalidates the session key. Worker function that does
# the work of release_session_key.
#
#                   **** DO NOT CALL DIRECTLY ****
#
# unless you want your session key released immediately, possibly
# preventing asynchronous tasks from completing
#
#----------------------------------------------------------------------------
sub release_session_key_private__
{
    my ( $self, $session ) = @_;

    if ( defined( $self->{api_sessions__}{$session} ) ) {
        $self->log_( 1, "release_session_key releasing key $session for user $self->{api_sessions__}{$session}" );
        delete $self->{api_sessions__}{$session};
    }
}

#----------------------------------------------------------------------------
#
# valid_session_key__
#
# $session                Session key returned by call to get_session_key
#
# Returns undef is the session key is not valid, or returns the user
# ID associated with the session key which can be used in database
# accesses
#
#----------------------------------------------------------------------------
sub valid_session_key__
{
    my ( $self, $session ) = @_;

    # This provides protection against someone using the XML-RPC
    # interface and calling this API directly to fish for session
    # keys, this must be called from within this module

    return undef if ( caller ne 'Classifier::Bayes' );

    # If the session key is invalid then wait 1 second.  This is done
    # to prevent people from calling a POPFile API such as
    # get_bucket_count with random session keys fishing for a valid
    # key.  The XML-RPC API is single threaded and hence this will
    # delay all use of that API by one second.  Of course in normal
    # use when the user knows the username/password or session key
    # then there is no delay

    if ( !defined( $self->{api_sessions__}{$session} ) ) {
        my ( $package, $filename, $line, $subroutine ) = caller;
        $self->log_( 0, "Invalid session key $session provided in $package @ $line" );
        select( undef, undef, undef, 1 );
    }

    return $self->{api_sessions__}{$session};
}

#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# _____   _____   _____  _______ _____        _______   _______  _____  _____
#|_____] |     | |_____] |______   |   |      |______   |_____| |_____]   |
#|       |_____| |       |       __|__ |_____ |______   |     | |       __|__
#
# The method below are public and may be accessed by other modules.
# All of them may be accessed remotely through the XMLRPC.pm module
# using the XML-RPC protocol
#
# Note that every API function expects to be passed a $session which
# is obtained by first calling get_session_key with a valid username
# and password.  Once done call the method release_session_key.
#
# See POPFile::API for more details
#
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

#----------------------------------------------------------------------------
#
# get_session_key
#
# $user           The name of an existing user
# $pwd            The user's password
#
# Returns a string based session key if the username and password
# match, or undef if not
#
#----------------------------------------------------------------------------
sub get_session_key
{
    my ( $self, $user, $pwd ) = @_;

    # The password is stored in the database as an MD5 hash of the
    # username and password concatenated and separated by the string
    # __popfile__, so compute the hash here

    my $hash = md5_hex( $user . '__popfile__' . $pwd );

    $self->validate_sql_prepare_and_execute(      # PROFILE BLOCK START
        $self->{db_get_userid__}, $user, $hash ); # PROFILE BLOCK STOP
    my $result = $self->{db_get_userid__}->fetchrow_arrayref;
    if ( !defined( $result ) ) {

        # The delay of one second here is to prevent people from trying out
        # username/password combinations at high speed to determine the
        # credentials of a valid user

        $self->log_( 0, "Attempt to login with incorrect credentials for user $user" );
        select( undef, undef, undef, 1 );
        return undef;
    }

    my $session = $self->generate_unique_session_key__();

    $self->{api_sessions__}{$session} = $result->[0];

    $self->db_update_cache__( $session );

    $self->log_( 1, "get_session_key returning key $session for user $self->{api_sessions__}{$session}" );

    return $session;
}

#----------------------------------------------------------------------------
#
# release_session_key
#
# $session        A session key previously returned by get_session_key
#
# Releases and invalidates the session key
#
#----------------------------------------------------------------------------
sub release_session_key
{
    my ( $self, $session ) = @_;

    $self->mq_post_( "RELSE", $session );
}


#----------------------------------------------------------------------------
#
# get_top_bucket__
#
# Helper function used by classify to get the bucket with the highest
# score from data stored in a matrix of information (see definition of
# %matrix in classify for details) and a list of potential buckets
#
# $userid         User ID for database access
# $id             ID of a word in $matrix
# $matrix         Reference to the %matrix hash in classify
# $buckets        Reference to a list of buckets
#
# Returns the bucket in $buckets with the highest score
#
#----------------------------------------------------------------------------
sub get_top_bucket__
{
    my ( $self, $userid, $id, $matrix, $buckets ) = @_;

    my $best_probability = 0;
    my $top_bucket       = 'unclassified';

    for my $bucket (@$buckets) {
        my $probability = 0;
        if ( defined($$matrix{$id}{$bucket}) && ( $$matrix{$id}{$bucket} > 0 ) ) {
            $probability = $$matrix{$id}{$bucket} / $self->{db_bucketcount__}{$userid}{$bucket};
        }

        if ( $probability > $best_probability ) {
            $best_probability = $probability;
            $top_bucket       = $bucket;
        }
    }

    return $top_bucket;
}

#----------------------------------------------------------------------------
#
# classify
#
# $session   A valid session key returned by a call to get_session_key
# $file The name of the file containing the text to classify (or undef
# to use the data already in the parser)
# $templ     Reference to the UI template used for word score display
# $matrix (optional) Reference to a hash that will be filled with the
# word matrix used in classification
# $idmap (optional) Reference to a hash that will map word ids in the
# $matrix to actual words
#
# Splits the mail message into valid words, then runs the Bayes
# algorithm to figure out which bucket it belongs in.  Returns the
# bucket name
#
#----------------------------------------------------------------------------
sub classify
{
    my ( $self, $session, $file, $templ, $matrix, $idmap ) = @_;
    my $msg_total = 0;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    $self->{unclassified__} = log( $self->config_( 'unclassified_weight' ) );

    $self->{magnet_used__}   = 0;
    $self->{magnet_detail__} = 0;

    if ( defined( $file ) ) {
        return undef if ( !-f $file );

        $self->{parser__}->parse_file( $file,                                           # PROFILE BLOCK START
                                       $self->global_config_( 'message_cutoff'   ) );   # PROFILE BLOCK STOP
    }

    # Get the list of buckets

    my @buckets = $self->get_buckets( $session );

    # If the user has not defined any buckets then we escape here
    # return unclassified

    return "unclassified" if ( $#buckets == -1 );

    # If all of the user's buckets have no words then we escape here
    # return unclassified
    # $self->{not_likely__}{$userid} is 0 if word count is 0.
    # See: update_constants__()

    return "unclassified" if ( $self->{not_likely__}{$userid} == 0 );

    # Check to see if this email should be classified based on a magnet

    for my $bucket ($self->get_buckets_with_magnets( $session ))  {
        for my $type ($self->get_magnet_types_in_bucket( $session, $bucket )) {
            if ( $self->magnet_match__( $session, $self->{parser__}->get_header($type), $bucket, $type ) ) {
                return $bucket;
            }
        }
    }

    # The score hash will contain the likelihood that the given
    # message is in each bucket, the buckets are the keys for score

    # Set up the initial score as P(bucket)

    my %score;
    my %matchcount;

    # Build up a list of the buckets that are OK to use for
    # classification (i.e.  that have at least one word in them).

    my @ok_buckets;

    for my $bucket (@buckets) {
        if ( defined $self->{bucket_start__}{$userid}{$bucket} && $self->{bucket_start__}{$userid}{$bucket} != 0 ) {
            $score{$bucket} = $self->{bucket_start__}{$userid}{$bucket};
            $matchcount{$bucket} = 0;
            push @ok_buckets, ( $bucket );
        }
    }

    @buckets = @ok_buckets;

    # If the user does not have at least two buckets which contains
    # some words then we escape here return unclassified

    return "unclassified" if ( $#buckets < 1 );

    # For each word go through the buckets and calculate
    # P(word|bucket) and then calculate P(word|bucket) ^ word count
    # and multiply to the score

    my $word_count = 0;

    # The correction value is used to generate score displays variable
    # which are consistent with the word scores shown by the GUI's
    # word lookup feature.  It is computed to make the contribution of
    # a word which is unrepresented in a bucket zero.  This correction
    # affects only the values displayed in the display; it has no
    # effect on the classification process.

    my $correction = 0;

    # Classification against the database works in a sequence of steps
    # to get the fastest time possible.  The steps are as follows:
    #
    # 1. Convert the list of words returned by the parser into a list
    #    of unique word ids that can be used in the database.  This
    #    requires a select against the database to get the word ids
    #    (and associated words) which is then converted into two
    #    things: @id_list which is just the sorted list of word ids
    #    and %idmap which maps a word to its id.
    #
    # 2. Then run a second select that get the triplet (count, id,
    #    bucket) for each word id and each bucket.  The triplet
    #    contains the word count from the database for each bucket and
    #    each id, where there is an entry. That data gets loaded into
    #    the sparse matrix %matrix.
    #
    # 3. Do the normal classification loop as before running against
    # the @id_list for the words and for each bucket.  If there's an
    # entry in %matrix for the id/bucket combination then calculate
    # the probability, otherwise use the not_likely probability.
    #
    # NOTE.  Since there is a single not_likely probability we do not
    # worry about the fact that the select in 1 might return a shorter
    # list of words than was found in the message (because some words
    # are not in the database) since the missing words will be the
    # same for all buckets and hence constitute a fixed scaling factor
    # on all the buckets which is irrelevant in deciding which the
    # winning bucket is.

    my $words;
    $words = join( ',', map( $self->{db__}->quote( $_ ), (sort keys %{$self->{parser__}{words__}}) ) );
    $self->{get_wordids__} = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
             "select id, word
                  from words
                  where word in ( $words )
                  order by id;" );                    # PROFILE BLOCK STOP

    my @id_list;
    my %temp_idmap;
    my ( $wordid, $word );

    if ( !defined( $idmap ) ) {
        $idmap = \%temp_idmap;
    }

    $self->{get_wordids__}->bind_columns( \$wordid, \$word );
    while ( $self->{get_wordids__}->fetchrow_arrayref ) {
        push @id_list, $wordid;
        $$idmap{$wordid} = $word;
    }

    $self->{get_wordids__}->finish;
    undef $self->{get_wordids__};

    my $ids = join( ',', @id_list );

    $self->{db_classify__} = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
             "select matrix.times, matrix.wordid, buckets.name
                  from matrix, buckets
                  where matrix.wordid in ( $ids )
                    and matrix.bucketid = buckets.id
                    and buckets.userid = ?;", $userid );               # PROFILE BLOCK STOP

    # %matrix maps wordids and bucket names to counts
    # $matrix{$wordid}{$bucket} == $count

    my %temp_matrix;
    my ( $count, $bucketname );

    if ( !defined( $matrix ) ) {
        $matrix = \%temp_matrix;
    }

    $self->{db_classify__}->bind_columns( \$count, \$wordid, \$bucketname );
    while ( $self->{db_classify__}->fetchrow_arrayref ) {
        $$matrix{$wordid}{$bucketname} = $count;
    }

    $self->{db_classify__}->finish;
    undef $self->{db_classify__};

    my $not_likely = $self->{not_likely__}{$userid};

    foreach my $id (@id_list) {
        $word_count += 2;
        my $wmax = -10000;
        my $count = $self->{parser__}{words__}{$$idmap{$id}};

        foreach my $bucket (@buckets) {
            my $probability = $not_likely;

            if ( defined($$matrix{$id}{$bucket}) && ( $$matrix{$id}{$bucket} > 0 ) ) {
                $probability = log( $$matrix{$id}{$bucket} / $self->{db_bucketcount__}{$userid}{$bucket} );
                $matchcount{$bucket} += $count;
            }

            $wmax = $probability if ( $wmax < $probability );
            $score{$bucket} += ( $probability * $count );
        }

        if ( $wmax > $not_likely ) {
            $correction += $not_likely * $count;
        } else {
            $correction += $wmax * $count;
        }
    }

    # Now sort the scores to find the highest and return that bucket
    # as the classification

    my @ranking = sort {$score{$b} <=> $score{$a}} keys %score;

    my %raw_score;
    my $base_score = defined $ranking[0] ? $score{$ranking[0]} : 0;
    my $total = 0;

    # If the first and second bucket are too close in their
    # probabilities, call the message unclassified.  Also if there are
    # fewer than 2 buckets.

    my $class = 'unclassified';

    if ( @buckets > 1 && $score{$ranking[0]} > ( $score{$ranking[1]} + $self->{unclassified__} ) ) {
        $class = $ranking[0];
    }

    # Compute the total of all the scores to generate the normalized
    # scores and probability estimate.  $total is always 1 after the
    # first loop iteration, so any additional term less than 2 ** -54
    # is insignificant, and need not be computed.

    my $ln2p_54 = -54 * log(2);

    foreach my $b (@ranking) {
        $raw_score{$b} = $score{$b};
        $score{$b} -= $base_score;

        $total += exp($score{$b}) if ($score{$b} > $ln2p_54 );
    }

    if ($self->{wordscores__} && defined($templ) ) {
        my %qm = %{$self->{parser__}->quickmagnets()};
        my $mlen = scalar(keys %{$self->{parser__}->quickmagnets()});

        if ( $mlen > 0 ) {
            $templ->param( 'View_QuickMagnets_If' => 1 );
            $templ->param( 'View_QuickMagnets_Count' => ($mlen + 1) );
            my @buckets = $self->get_buckets( $session );
            my $i = 0;
            my %types = $self->get_magnet_types( $session );

            my @bucket_data;
            foreach my $bucket (@buckets) {
                my %row_data;
                $row_data{View_QuickMagnets_Bucket} = $bucket;
                $row_data{View_QuickMagnets_Bucket_Color} = $self->get_bucket_color( $session, $bucket );
                push ( @bucket_data, \%row_data );
            }

            my @qm_data;
            foreach my $type (sort keys %types) {
                my %row_data;

                if (defined $qm{$type}) {
                    $i++;

                    $row_data{View_QuickMagnets_Type} = $type;
                    $row_data{View_QuickMagnets_I} = $i;
                    $row_data{View_QuickMagnets_Loop_Buckets} = \@bucket_data;

                    my @magnet_data;
                    foreach my $magnet ( @{$qm{$type}} ) {
                        my %row_magnet;
                        $row_magnet{View_QuickMagnets_Magnet} = $magnet;
                        push ( @magnet_data, \%row_magnet );
                    }
                    $row_data{View_QuickMagnets_Loop_Magnets} = \@magnet_data;

                    push ( @qm_data, \%row_data );
                }
            }
            $templ->param( 'View_QuickMagnets_Loop' => \@qm_data );
        }

        $templ->param( 'View_Score_If_Score' => $self->{wmformat__} eq 'score' );
        my $log10 = log(10.0);

        my @score_data;
        foreach my $b (@ranking) {
            my %row_data;
            my $prob = exp($score{$b})/$total;
            my $probstr;
            my $rawstr;

            # If the computed probability would display as 1, display
            # it as .999999 instead.  We don't want to give the
            # impression that POPFile is ever completely sure of its
            # classification.

            if ($prob >= .999999) {
                $probstr = sprintf("%12.6f", 0.999999);
            } else {
                if ($prob >= 0.1 || $prob == 0.0) {
                    $probstr = sprintf("%12.6f", $prob);
                } else {
                    $probstr = sprintf("%17.6e", $prob);
                }
            }

            my $color = $self->get_bucket_color( $session, $b );

            $row_data{View_Score_Bucket} = $b;
            $row_data{View_Score_Bucket_Color} = $color;
            $row_data{View_Score_MatchCount} = $matchcount{$b};
            $row_data{View_Score_ProbStr} = $probstr;

            if ( $self->{wmformat__} eq 'score' ) {
                $row_data{View_Score_If_Score} = 1;
                $rawstr = sprintf("%12.6f", ($raw_score{$b} - $correction)/$log10);
                $row_data{View_Score_RawStr} = $rawstr;
            }
            push ( @score_data, \%row_data );
        }
        $templ->param( 'View_Score_Loop_Scores' => \@score_data );

        if ( $self->{wmformat__} ne '' ) {
            $templ->param( 'View_Score_If_Table' => 1 );

            my @header_data;
            foreach my $ix (0..($#buckets > 7? 7: $#buckets)) {
                my %row_data;
                my $bucket = $ranking[$ix];
                my $bucketcolor  = $self->get_bucket_color( $session, $bucket );
                $row_data{View_Score_Bucket} = $bucket;
                $row_data{View_Score_Bucket_Color} = $bucketcolor;
                push ( @header_data, \%row_data );
            }
            $templ->param( 'View_Score_Loop_Bucket_Header' => \@header_data );

            my %wordprobs;

            # If the word matrix is supposed to show probabilities,
            # compute them, saving the results in %wordprobs.

            if ( $self->{wmformat__} eq 'prob' ) {
                foreach my $id (@id_list) {
                    my $sumfreq = 0;
                    my %wval;
                    foreach my $bucket (@ranking) {
                        $wval{$bucket} = $$matrix{$id}{$bucket} || 0;
                        $sumfreq += $wval{$bucket};
                    }

                    # If $sumfreq is still zero then this word didn't
                    # appear in any buckets so we shouldn't create
                    # wordprobs entries for it

                    if ( $sumfreq != 0 ) {
                        foreach my $bucket (@ranking) {
                            $wordprobs{$bucket,$id} = $wval{$bucket} / $sumfreq;
                        }
                    }
                }
            }

            my @ranked_ids;
            if ( $self->{wmformat__} eq 'prob' ) {
                @ranked_ids = sort {($wordprobs{$ranking[0],$b}||0) <=> ($wordprobs{$ranking[0],$a}||0)} @id_list;
            } else {
                @ranked_ids = sort {($$matrix{$b}{$ranking[0]}||0) <=> ($$matrix{$a}{$ranking[0]}||0)} @id_list;
            }

            my @word_data;
            my %chart;
            foreach my $id (@ranked_ids) {
                my %row_data;
                my $known = 0;

                foreach my $bucket (@ranking) {
                    if ( defined( $$matrix{$id}{$bucket} ) ) {
                        $known = 1;
                        last;
                    }
                }

                if ( $known == 1 ) {
                    my $wordcolor = $self->get_bucket_color( $session, $self->get_top_bucket__( $userid, $id, $matrix, \@ranking ) );
                    my $count = $self->{parser__}->{words__}{$$idmap{$id}};

                    $row_data{View_Score_Word} = $$idmap{$id};
                    $row_data{View_Score_Word_Color} = $wordcolor;
                    $row_data{View_Score_Word_Count} = $count;

                    my $base_probability = 0;
                    if ( defined($$matrix{$id}{$ranking[0]}) && ( $$matrix{$id}{$ranking[0]} > 0 ) ) {
                        $base_probability = log( $$matrix{$id}{$ranking[0]} / $self->{db_bucketcount__}{$userid}{$ranking[0]} );
                    }

                    my @per_bucket;
                    my @score;
                    foreach my $ix (0..($#buckets > 7? 7: $#buckets)) {
                        my %bucket_row;
                        my $bucket = $ranking[$ix];
                        my $probability = 0;
                        if ( defined($$matrix{$id}{$bucket}) && ( $$matrix{$id}{$bucket} > 0 ) ) {
                            $probability = log( $$matrix{$id}{$bucket} / $self->{db_bucketcount__}{$userid}{$bucket} );
                        }
                        my $color = 'black';

                        if ( $probability >= $base_probability || $base_probability == 0 ) {
                            $color = $self->get_bucket_color( $session, $bucket );
                        }

                        $bucket_row{View_Score_If_Probability} = ( $probability != 0 );
                        $bucket_row{View_Score_Word_Color} = $color;
                        if ( $probability != 0 ) {
                            my $wordprobstr;
                            if ($self->{wmformat__} eq 'score') {
                                $wordprobstr  = sprintf("%12.4f", ($probability - $self->{not_likely__}{$userid})/$log10 );
                                push ( @score, $wordprobstr );
                            } else {
                                if ($self->{wmformat__} eq 'prob') {
                                    $wordprobstr  = sprintf("%12.4f", $wordprobs{$bucket,$id});
                                } else {
                                    $wordprobstr  = sprintf("%13.5f", exp($probability) );
                                }
                            }
                            $bucket_row{View_Score_Probability} = $wordprobstr;
                        }
                        else {
                            # Scores eq 0 must also be remembered.
                            push @score, 0;
                        }
                        push ( @per_bucket, \%bucket_row );
                    }
                    $row_data{View_Score_Loop_Per_Bucket} = \@per_bucket;

                    # If we are doing the word scores then we build up
                    # a hash that maps the name of a word to a value
                    # which is the difference between the word scores
                    # for the top two buckets.  We later use this to
                    # draw a chart

                    if ( $self->{wmformat__} eq 'score' ) {
                        $chart{$$idmap{$id}} = ( $score[0] || 0 ) - ( $score[1] || 0 );
                    }

                    push ( @word_data, \%row_data );
                }
            }
            $templ->param( 'View_Score_Loop_Words' => \@word_data );

            if ( $self->{wmformat__} eq 'score' ) {
                # Draw a chart that shows how the decision between the top
                # two buckets was made.

                my @words = sort { $chart{$b} <=> $chart{$a} } keys %chart;

                my @chart_data;
                my $max_chart = $chart{$words[0]};
                my $min_chart = $chart{$words[$#words]};
                my $scale = ( $max_chart > $min_chart ) ? 400 / ( $max_chart - $min_chart ) : 0;

                my $color_1 = $self->get_bucket_color( $session, $ranking[0] );
                my $color_2 = $self->get_bucket_color( $session, $ranking[1] );

                $templ->param( 'Bucket_1' => $ranking[0] );
                $templ->param( 'Bucket_2' => $ranking[1] );

                $templ->param( 'Color_Bucket_1' => $color_1 );
                $templ->param( 'Color_Bucket_2' => $color_2 );

                $templ->param( 'Score_Bucket_1' => sprintf("%.3f", ($raw_score{$ranking[0]} - $correction)/$log10) );
                $templ->param( 'Score_Bucket_2' => sprintf("%.3f", ($raw_score{$ranking[1]} - $correction)/$log10) );

                for ( my $i=0; $i <= $#words; $i++ ) {
                    my $word_1 = $words[$i];
                    my $word_2 = $words[$#words - $i];

                    my $width_1 = int( $chart{$word_1} * $scale + .5 );
                    my $width_2 = int( $chart{$word_2} * $scale - .5 ) * -1;

                    last if ( $width_1 <=0 && $width_2 <= 0 );

                    my %row_data;

                    $row_data{View_Chart_Word_1} = $word_1;
                    if ( $width_1 > 0 ) {
                        $row_data{View_If_Bar_1} = 1;
                        $row_data{View_Width_1}  = $width_1;
                        $row_data{View_Color_1}  = $color_1;
                        $row_data{Score_Word_1}  = sprintf "%.3f", $chart{$word_1};
                    }
                    else {
                        $row_data{View_If_Bar_1} = 0;
                    }

                    $row_data{View_Chart_Word_2} = $word_2;
                    if ( $width_2 > 0 ) {
                        $row_data{View_If_Bar_2} = 1;
                        $row_data{View_Width_2}  = $width_2;
                        $row_data{View_Color_2}  = $color_2;
                        $row_data{Score_Word_2}  = sprintf "%.3f", $chart{$word_2};
                    }
                    else {
                        $row_data{View_If_Bar_2} = 0;
                    }

                    push ( @chart_data, \%row_data );
                }
                $templ->param( 'View_Loop_Chart' => \@chart_data );
                $templ->param( 'If_chart' => 1 );
            }
            else {
                $templ->param( 'If_chart' => 0 );
            }
        }
    }

    return $class;
}

#----------------------------------------------------------------------------
#
# classify_and_modify
#
# This method reads an email terminated by . on a line by itself (or
# the end of stream) from a handle and creates an entry in the
# history, outputting the same email on another handle with the
# appropriate header modifications and insertions
#
# $session  - A valid session key returned by a call to get_session_key
# $mail     - an open stream to read the email from
# $client   - an open stream to write the modified email to
# $nosave   - set to 1 indicates that this should not save to history
# $class    - if we already know the classification
# $slot     - Must be defined if $class is set
# $echo     - 1 to echo to the client, 0 to supress, defaults to 1
# $crlf     - The sequence to use at the end of a line in the output,
#   normally this is left undefined and this method uses $eol (the
#   normal network end of line), but if this method is being used with
#   real files you may wish to pass in \n instead
#
# Returns a classification if it worked and the slot ID of the history
# item related to this classification
#
# IMPORTANT NOTE: $mail and $client should be binmode
#
#----------------------------------------------------------------------------
sub classify_and_modify
{
    my ( $self, $session, $mail, $client, $nosave, $class, $slot, $echo, $crlf ) = @_;

    $echo = 1    unless (defined $echo);
    $crlf = $eol unless (defined $crlf);

    my $msg_subject;              # The message subject
    my $msg_head_before = '';     # Store the message headers that
                                  # come before Subject here
    my $msg_head_after = '';      # Store the message headers that
                                  # come after Subject here
    my $msg_head_q      = '';     # Store questionable header lines here
    my $msg_body        = '';     # Store the message body here
    my $in_subject_header = 0;    # 1 if in Subject header

    # These two variables are used to control the insertion of the
    # X-POPFile-TimeoutPrevention header when downloading long or slow
    # emails

    my $last_timeout   = time;
    my $timeout_count  = 0;

    # Indicates whether the first time through the receive loop we got
    # the full body, this will happen on small emails

    my $got_full_body  = 0;

    # The size of the message downloaded so far.

    my $message_size   = 0;

    # The classification for this message

    my $classification = '';

    # Whether we are currently reading the mail headers or not

    my $getting_headers = 1;

    # The maximum size of message to parse, or 0 for unlimited

    my $max_size = $self->global_config_( 'message_cutoff' );
    $max_size = 0 if ( !defined( $max_size ) || ( $max_size =~ /\D/ ) );

    my $msg_file;

    # If we don't yet know the classification then start the parser

    $class = '' if ( !defined( $class ) );
    if ( $class eq '' ) {
        $self->{parser__}->start_parse();
        ( $slot, $msg_file ) = $self->{history__}->reserve_slot();
    } else {
        $msg_file = $self->{history__}->get_slot_file( $slot );
    }

    # We append .TMP to the filename for the MSG file so that if we are in
    # middle of downloading a message and we refresh the history we do not
    # get class file errors

    if ( !$nosave ) {
        open MSG, ">$msg_file" or $self->log_( 0, "Could not open $msg_file : $!" );
    }

    while ( my $line = $self->slurp_( $mail ) ) {
        my $fileline;

        # This is done so that we remove the network style end of line
        # CR LF and allow Perl to decide on the local system EOL which
        # it will expand out of \n when this gets written to the temp
        # file

        $fileline = $line;
        $fileline =~ s/[\r\n]//g;
        $fileline .= "\n";

        # Check for an abort

        last if ( $self->{alive_} == 0 );

        # The termination of a message is a line consisting of exactly
        # .CRLF so we detect that here exactly

        if ( $line =~ /^\.(\r\n|\r|\n)$/ ) {
            $got_full_body = 1;
            last;
        }

        if ( $getting_headers )  {

            # Kill header lines containing only whitespace (Exim does this)

            next if ( $line =~ /^[ \t]+(\r\n|\r|\n)$/i );

            if ( !( $line =~ /^(\r\n|\r|\n)$/i ) )  {
                $message_size += length $line;
                $self->write_line__( $nosave?undef:\*MSG, $fileline, $class );

                # If there is no echoing occuring, it doesn't matter
                # what we do to these

                if ( $echo ) {
                    if ( $line =~ /^Subject:(.*)/i )  {
                        $msg_subject = $1;
                        $msg_subject =~ s/(\012|\015)//g;
                        $in_subject_header = 1;
                        next;
                    } elsif ( $line !~ /^[ \t]/ ) {
                        $in_subject_header = 0;
                    }

                    # Strip out the X-Text-Classification header that
                    # is in an incoming message

                    next if ( $line =~ /^X-Text-Classification:/i );
                    next if ( $line =~ /^X-POPFile-Link:/i );

                    # Store any lines that appear as though they may
                    # be non-header content Lines that are headers
                    # begin with whitespace or Alphanumerics and "-"
                    # followed by a colon.
                    #
                    # This prevents weird things like HTML before the
                    # headers terminate from causing the XPL and XTC
                    # headers to be inserted in places some clients
                    # can't detect

                    if ( ( $line =~ /^[ \t]/ ) && $in_subject_header ) {
                        $line =~ s/(\012|\015)//g;
                        $msg_subject .= $crlf . $line;
                        next;
                    }

                    if ( $line =~ /^([ \t]|([A-Z0-9\-_]+:))/i ) {
                        if ( !defined($msg_subject) )  {
                            $msg_head_before .= $msg_head_q . $line;
                        } else {
                            $msg_head_after  .= $msg_head_q . $line;
                        }
                        $msg_head_q = '';
                    } else {

                        # Gather up any header lines that are questionable

                        $self->log_( 1, "Found odd email header: $line" );
                        $msg_head_q .= $line;
                    }
                }
            } else {
                $self->write_line__( $nosave?undef:\*MSG, "\n", $class );
                $message_size += length $crlf;
                $getting_headers = 0;
            }
        } else {
            $message_size += length $line;
            $msg_body     .= $line;
            $self->write_line__( $nosave?undef:\*MSG, $fileline, $class );
        }

        # Check to see if too much time has passed and we need to keep
        # the mail client happy

        if ( time > ( $last_timeout + 2 ) ) {
            print $client "X-POPFile-TimeoutPrevention: $timeout_count$crlf" if ( $echo );
            $timeout_count += 1;
            $last_timeout = time;
        }

        last if ( ( $max_size > 0 ) &&               # PROFILE BLOCK START
                  ( $message_size > $max_size ) &&
                  ( !$getting_headers ) );           # PROFILE BLOCK STOP
    }

    close MSG unless $nosave;

    # If we don't yet know the classification then stop the parser
    if ( $class eq '' ) {
        $self->{parser__}->stop_parse();
    }

    # Do the text classification and update the counter for that
    # bucket that we just downloaded an email of that type

    $classification = ($class ne '')?$class:$self->classify( $session, undef);

    my $subject_modification = $self->get_bucket_parameter( $session, $classification, 'subject'    );
    my $xtc_insertion        = $self->get_bucket_parameter( $session, $classification, 'xtc'        );
    my $xpl_insertion        = $self->get_bucket_parameter( $session, $classification, 'xpl'        );
    my $quarantine           = $self->get_bucket_parameter( $session, $classification, 'quarantine' );

    my $modification = $self->config_( 'subject_mod_left' ) . $classification . $self->config_( 'subject_mod_right' );

    # Add the Subject line modification or the original line back again
    # Don't add the classification unless it is not present

    my $original_msg_subject = $msg_subject;

    if ( $subject_modification ) {
        if ( !defined( $msg_subject ) ) {   # PROFILE BLOCK START
            $msg_subject = " $modification";
        } elsif ( $msg_subject !~ /\Q$modification\E/ ) {
            if ( $self->config_( 'subject_mod_pos' ) > 0 ) {
                # Beginning
                $msg_subject = " $modification$msg_subject";
            } else {
                # End
                $msg_subject = "$msg_subject $modification";
            }
        }                                   # PROFILE BLOCK STOP
    }

    if ( $quarantine ) {
        if ( defined( $original_msg_subject ) ) {
            $msg_head_before .= "Subject:$original_msg_subject$crlf";
        }
    } else {
        if ( defined( $msg_subject ) ) {
            $msg_head_before .= "Subject:$msg_subject$crlf";
        }
    }

    # Add LF if $msg_head_after ends with CR to avoid header concatination

    $msg_head_after =~ s/\015\z/$crlf/;

    # Add the XTC header

    if ( ( $xtc_insertion ) && ( !$quarantine ) ) {
        $msg_head_after .= "X-Text-Classification: $classification$crlf";
    }

    # Add the XPL header

    my $host = $self->module_config_( 'html', 'local' ) ?   # PROFILE BLOCK START
            $self->config_( 'localhostname' ) || '127.0.0.1' :
            $self->config_( 'hostname' );                   # PROFILE BLOCK STOP
    my $port = $self->module_config_( 'html', 'port' );

    my $xpl = "http://$host:$port/jump_to_message?view=$slot";

    $xpl = "<$xpl>" if ( $self->config_( 'xpl_angle' ) );

    if ( ( $xpl_insertion ) && ( !$quarantine ) ) {
        $msg_head_after .= "X-POPFile-Link: $xpl$crlf";
    }

    $msg_head_after .= $msg_head_q;
    $msg_head_after .= $crlf if ( !$getting_headers );

    # Echo the text of the message to the client

    if ( $echo ) {

        # If the bucket is quarantined then we'll treat it specially
        # by changing the message header to contain information from
        # POPFile and wrapping the original message in a MIME encoding

       if ( $quarantine ) {
           my ( $orig_from, $orig_to, $orig_subject ) = ( $self->{parser__}->get_header('from'), $self->{parser__}->get_header('to'), $self->{parser__}->get_header('subject') );
           my ( $encoded_from, $encoded_to ) = ( $orig_from, $orig_to );
           if ( $self->{parser__}->{lang__} eq 'Nihongo' ) {
               require Encode;

               Encode::from_to( $orig_from, 'euc-jp', 'iso-2022-jp');
               Encode::from_to( $orig_to, 'euc-jp', 'iso-2022-jp');
               Encode::from_to( $orig_subject, 'euc-jp', 'iso-2022-jp');

               $encoded_from = $orig_from;
               $encoded_to = $orig_to;
               $encoded_from =~ s/(\x1B\x24\x42.+\x1B\x28\x42)/"=?ISO-2022-JP?B?" . encode_base64($1,'') . "?="/eg;
               $encoded_to =~ s/(\x1B\x24\x42.+\x1B\x28\x42)/"=?ISO-2022-JP?B?" . encode_base64($1,'') . "?="/eg;
           }

           print $client "From: $encoded_from$crlf";
           print $client "To: $encoded_to$crlf";
           print $client "Date: " . $self->{parser__}->get_header( 'date' ) . "$crlf";
           print $client "Subject:$msg_subject$crlf" if ( defined( $msg_subject ) );
           print $client "X-Text-Classification: $classification$crlf" if ( $xtc_insertion );
           print $client "X-POPFile-Link: $xpl$crlf" if ( $xpl_insertion );
           print $client "MIME-Version: 1.0$crlf";
           print $client "Content-Type: multipart/report; boundary=\"$slot\"$crlf$crlf--$slot$crlf";
           print $client "Content-Type: text/plain";
           print $client "; charset=iso-2022-jp" if ( $self->{parser__}->{lang__} eq 'Nihongo' );
           print $client "$crlf$crlf";
           print $client "POPFile has quarantined a message.  It is attached to this email.$crlf$crlf";
           print $client "Quarantined Message Detail$crlf$crlf";

           print $client "Original From: $orig_from$crlf";
           print $client "Original To: $orig_to$crlf";
           print $client "Original Subject: $orig_subject$crlf";

           print $client "To examine the email open the attachment. ";
           print $client "To change this mail's classification go to $xpl$crlf";
           print $client "$crlf";
           print $client "The first 20 words found in the email are:$crlf$crlf";

           my $first20 = $self->{parser__}->first20();
           if ( $self->{parser__}->{lang__} eq 'Nihongo' ) {
               require Encode;

               Encode::from_to( $first20, 'euc-jp', 'iso-2022-jp');
           }

           print $client $first20;
           print $client "$crlf--$slot$crlf";
           print $client "Content-Type: message/rfc822$crlf$crlf";
        }

        print $client $msg_head_before;
        print $client $msg_head_after;
        print $client $msg_body;
    }

    my $before_dot = '';

    if ( $quarantine && $echo ) {
        $before_dot = "$crlf--$slot--$crlf";
    }

    my $need_dot = 0;

    if ( $got_full_body ) {
        $need_dot = 1;
    } else {
        $need_dot = !$self->echo_to_dot_( $mail, $echo?$client:undef, $nosave?undef:'>>' . $msg_file, $before_dot ) && !$nosave;
    }

    if ( $need_dot ) {
        print $client $before_dot if ( $before_dot ne '' );
        print $client ".$crlf"    if ( $echo );
    }

    # In some cases it's possible (and totally illegal) to get a . in
    # the middle of the message, to cope with the we call flush_extra_
    # here to remove any extra stuff the POP3 server is sending Make
    # sure to supress output if we are not echoing, and to save to
    # file if not echoing and saving

    if ( !($nosave || $echo) ) {

        # if we're saving (not nosave) and not echoing, we can safely
        # unload this into the temp file

        if (open FLUSH, ">$msg_file.flush") {
            binmode FLUSH;

            # TODO: Do this in a faster way (without flushing to one
            # file then copying to another) (perhaps a select on $mail
            # to predict if there is flushable data)

            $self->flush_extra_( $mail, \*FLUSH, 0 );
            close FLUSH;

            # append any data we got to the actual temp file

            if ( ( (-s "$msg_file.flush") > 0 ) &&        # PROFILE BLOCK START
                   ( open FLUSH, "<$msg_file.flush" ) ) { # PROFILE BLOCK STOP
                binmode FLUSH;
                if ( open TEMP, ">>$msg_file" ) {
                    binmode TEMP;

                    # The only time we get data here is if it is after
                    # a CRLF.CRLF We have to re-create it to avoid
                    # data-loss

                    print TEMP ".$crlf";

                    print TEMP $_ while (<FLUSH>);

                    # NOTE: The last line flushed MAY be a CRLF.CRLF,
                    # which isn't actually part of the message body

                    close TEMP;
                }
                close FLUSH;
            }
            unlink("$msg_file.flush");
        }
    } else {

        # if we are echoing, the client can make sure we have no data
        # loss otherwise, the data can be discarded (not saved and not
        # echoed)

        $self->flush_extra_( $mail, $client, $echo?0:1);
    }

    if ( $class eq '' ) {
        if ( $nosave ) {
            $self->{history__}->release_slot( $slot );
        } else {
            $self->{history__}->commit_slot( $session, $slot, $classification, $self->{magnet_detail__} );
        }
    }

    return ( $classification, $slot, $self->{magnet_used__} );
}

#----------------------------------------------------------------------------
#
# get_buckets
#
# Returns a list containing all the real bucket names sorted into
# alphabetic order
#
# $session   A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_buckets
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Note that get_buckets does not return pseudo buckets

    my @buckets;

    for my $b (sort keys %{$self->{db_bucketid__}{$userid}}) {
        if ( $self->{db_bucketid__}{$userid}{$b}{pseudo} == 0 ) {
            push @buckets, ($b);
        }
    }

    return @buckets;
}

#----------------------------------------------------------------------------
#
# get_bucket_id
#
# Returns the internal ID for a bucket for database calls
#
# $session   A valid session key returned by a call to get_session_key
# $bucket    The bucket name
#
#----------------------------------------------------------------------------
sub get_bucket_id
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );
    return undef if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) );

    return $self->{db_bucketid__}{$userid}{$bucket}{id};
}

#----------------------------------------------------------------------------
#
# get_bucket_name
#
# Returns the name of a bucket from an internal ID
#
# $session   A valid session key returned by a call to get_session_key
# $id        The bucket id
#
#----------------------------------------------------------------------------
sub get_bucket_name
{
    my ( $self, $session, $id ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    foreach $b (keys %{$self->{db_bucketid__}{$userid}}) {
        if ( $id == $self->{db_bucketid__}{$userid}{$b}{id} ) {
            return $b;
        }
    }

    return '';
}

#----------------------------------------------------------------------------
#
# get_pseudo_buckets
#
# Returns a list containing all the pseudo bucket names sorted into
# alphabetic order
#
# $session   A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_pseudo_buckets
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @buckets;

    for my $b (sort keys %{$self->{db_bucketid__}{$userid}}) {
        if ( $self->{db_bucketid__}{$userid}{$b}{pseudo} == 1 ) {
            push @buckets, ($b);
        }
    }

    return @buckets;
}

#----------------------------------------------------------------------------
#
# get_all_buckets
#
# Returns a list containing all the bucket names sorted into
# alphabetic order
#
# $session   A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_all_buckets
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @buckets;

    for my $b (sort keys %{$self->{db_bucketid__}{$userid}}) {
         push @buckets, ($b);
    }

    return @buckets;
}

#----------------------------------------------------------------------------
#
# is_pseudo_bucket
#
# Returns 1 if the named bucket is pseudo
#
# $session   A valid session key returned by a call to get_session_key
# $bucket    The bucket to check
#
#----------------------------------------------------------------------------
sub is_pseudo_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return ( defined($self->{db_bucketid__}{$userid}{$bucket})   # PROFILE BLOCK START
          && $self->{db_bucketid__}{$userid}{$bucket}{pseudo} ); # PROFILE BLOCK STOP
}

#----------------------------------------------------------------------------
#
# is_bucket
#
# Returns 1 if the named bucket is a bucket
#
# $session   A valid session key returned by a call to get_session_key
# $bucket    The bucket to check
#
#----------------------------------------------------------------------------
sub is_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return ( ( defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) &&  # PROFILE BLOCK START
             ( !$self->{db_bucketid__}{$userid}{$bucket}{pseudo} ) );    # PROFILE BLOCK STOP
}

#----------------------------------------------------------------------------
#
# get_bucket_word_count
#
# Returns the total word count (including duplicates) for the passed in bucket
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the word count is desired
#
#----------------------------------------------------------------------------
sub get_bucket_word_count
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $c = $self->{db_bucketcount__}{$userid}{$bucket};

    return defined($c)?$c:0;
}

#----------------------------------------------------------------------------
#
# get_bucket_word_list
#
# Returns a list of words all with the same first character
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the word count is desired
# $prefix      The first character of the words
#
#----------------------------------------------------------------------------
sub get_bucket_word_list
{
    my ( $self, $session, $bucket, $prefix ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return undef if ( !exists( $self->{db_bucketid__}{$userid}{$bucket} ) );
    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};

    $prefix = '' if ( !defined( $prefix ) );
    $prefix =~ s/\0//g;
    $prefix = $self->db_quote( "$prefix%" );

    my $result = $self->{db__}->selectcol_arrayref(    # PROFILE BLOCK START
        "select words.word from matrix, words
                where matrix.wordid   =    words.id and
                      matrix.bucketid =    $bucketid and
                      words.word      like $prefix;"); # PROFILE BLOCK STOP

    return @{$result};
}

#----------------------------------------------------------------------------
#
# get_bucket_word_prefixes
#
# Returns a list of all the initial letters of words in a bucket
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the word count is desired
#
#----------------------------------------------------------------------------
sub get_bucket_word_prefixes
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $prev = '';

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $result = $self->{db__}->selectcol_arrayref(   # PROFILE BLOCK START
        "select words.word from matrix, words
         where matrix.wordid  = words.id and
               matrix.bucketid = $bucketid;");        # PROFILE BLOCK STOP

    if ( $self->module_config_( 'html', 'language' ) eq 'Nihongo' ) {
        return grep {$_ ne $prev && ($prev = $_, 1)} sort map {substr_euc__($_,0,1)} @{$result};
    } else {
        if  ( $self->module_config_( 'html', 'language' ) eq 'Korean' ) {
            return grep {$_ ne $prev && ($prev = $_, 1)} sort map {$_ =~ /([\x20-\x80]|$eksc)/} @{$result};
        } else {
            return grep {$_ ne $prev && ($prev = $_, 1)} sort map {substr($_,0,1)}  @{$result};
        }
    }
}

#----------------------------------------------------------------------------
#
# get_word_count
#
# Returns the total word count (including duplicates)
#
# $session   A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_word_count
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $word_count = 0;
    foreach my $bucket ( keys %{$self->{db_bucketid__}{$userid}} ) {
        $word_count += $self->{db_bucketcount__}{$userid}{$bucket};
    }

    return $word_count;
}

#----------------------------------------------------------------------------
#
# get_count_for_word
#
# Returns the number of times the word occurs in a bucket
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          The bucket we are asking about
# $word            The word we are asking about
#
#----------------------------------------------------------------------------
sub get_count_for_word
{
    my ( $self, $session, $bucket, $word ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return $self->get_base_value_( $session, $bucket, $word );
}

#----------------------------------------------------------------------------
#
# get_bucket_unique_count
#
# Returns the unique word count (excluding duplicates) for the passed
# in bucket
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the word count is desired
#
#----------------------------------------------------------------------------
sub get_bucket_unique_count
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $c = $self->{db_bucketunique__}{$userid}{$bucket};

    return defined($c)?$c:0;
}

#----------------------------------------------------------------------------
#
# get_unique_word_count
#
# Returns the unique word count (excluding duplicates) for all buckets
#
# $session   A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_unique_word_count
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $unique_word_count = 0;
    foreach my $bucket ( keys %{$self->{db_bucketid__}{$userid}} ) {
        $unique_word_count += $self->{db_bucketunique__}{$userid}{$bucket};
    }

    return $unique_word_count;
}

#----------------------------------------------------------------------------
#
# get_bucket_color
#
# Returns the color associated with a bucket
#
# $session   A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the color is requested
#
# NOTE  This API is DEPRECATED in favor of calling get_bucket_parameter for
#       the parameter named 'color'
#----------------------------------------------------------------------------
sub get_bucket_color
{
    my ( $self, $session, $bucket ) = @_;

    return $self->get_bucket_parameter( $session, $bucket, 'color' );
}

#----------------------------------------------------------------------------
#
# set_bucket_color
#
# Returns the color associated with a bucket
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket for which the color is requested
# $color       The new color
#
# NOTE  This API is DEPRECATED in favor of calling set_bucket_parameter for
#       the parameter named 'color'
#----------------------------------------------------------------------------
sub set_bucket_color
{
    my ( $self, $session, $bucket, $color ) = @_;

    return $self->set_bucket_parameter( $session, $bucket, 'color', $color );
}

#----------------------------------------------------------------------------
#
# get_bucket_parameter
#
# Returns the value of a per bucket parameter
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket
# $parameter   The name of the parameter
#
#----------------------------------------------------------------------------
sub get_bucket_parameter
{
    my ( $self, $session, $bucket, $parameter ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # See if there's a cached value

    if ( defined( $self->{db_parameters__}{$userid}{$bucket}{$parameter} ) ) {
        return $self->{db_parameters__}{$userid}{$bucket}{$parameter};
    }

    # Make sure that the bucket passed in actually exists

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return undef;
    }

    # Make sure that the parameter is valid

    if ( !defined( $self->{db_parameterid__}{$parameter} ) ) {
        return undef;
    }

    # If there is a non-default value for this parameter then return it.

    $self->validate_sql_prepare_and_execute(     # PROFILE BLOCK START
        $self->{db_get_bucket_parameter__},
        $self->{db_bucketid__}{$userid}{$bucket}{id},
        $self->{db_parameterid__}{$parameter} ); # PROFILE BLOCK STOP
    my $result = $self->{db_get_bucket_parameter__}->fetchrow_arrayref;

    # If this parameter has not been defined for this specific bucket then
    # get the default value

    if ( !defined( $result ) ) {
        $self->validate_sql_prepare_and_execute(     # PROFILE BLOCK START
            $self->{db_get_bucket_parameter_default__},
            $self->{db_parameterid__}{$parameter} ); # PROFILE BLOCK STOP
        $result = $self->{db_get_bucket_parameter_default__}->fetchrow_arrayref;
    }

    if ( defined( $result ) ) {
        $self->{db_parameters__}{$userid}{$bucket}{$parameter} = $result->[0];
        return $result->[0];
    } else {
        return undef;
    }
}

#----------------------------------------------------------------------------
#
# set_bucket_parameter
#
# Sets the value associated with a bucket specific parameter
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The name of the bucket
# $parameter   The name of the parameter
# $value       The new value
#
#----------------------------------------------------------------------------
sub set_bucket_parameter
{
    my ( $self, $session, $bucket, $parameter, $value ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Make sure that the bucket passed in actually exists

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return undef;
    }

    # Make sure that the parameter is valid

    if ( !defined( $self->{db_parameterid__}{$parameter} ) ) {
        return undef;
    }

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $btid     = $self->{db_parameterid__}{$parameter};

    # Exactly one row should be affected by this statement

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        $self->{db_set_bucket_parameter__},
        $bucketid, $btid, $value );           # PROFILE BLOCK STOP

    if ( defined( $self->{db_parameters__}{$userid}{$bucket}{$parameter} ) ) {
        $self->{db_parameters__}{$userid}{$bucket}{$parameter} = $value;
    }

    return 1;
}

#----------------------------------------------------------------------------
#
# get_html_colored_message
#
# Parser a mail message stored in a file and returns HTML representing
# the message with coloring of the words
#
# $session        A valid session key returned by a call to get_session_key
# $file           The file to parse
#
#----------------------------------------------------------------------------
sub get_html_colored_message
{
    my ( $self, $session, $file ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    $self->{parser__}->{color__} = $session;
    $self->{parser__}->{color_matrix__} = undef;
    $self->{parser__}->{color_idmap__}  = undef;
    $self->{parser__}->{color_userid__} = undef;
    $self->{parser__}->{bayes__} = bless $self;

    my $result = $self->{parser__}->parse_file( $file,   # PROFILE BLOCK START
            $self->global_config_( 'message_cutoff' ) ); # PROFILE BLOCK STOP

    $self->{parser__}->{color__} = '';

    return $result;
}

#----------------------------------------------------------------------------
#
# fast_get_html_colored_message
#
# Parser a mail message stored in a file and returns HTML representing
# the message with coloring of the words
#
# $session        A valid session key returned by a call to get_session_key
# $file           The file to colorize
# $matrix         Reference to the matrix hash from a call to classify
# $idmap          Reference to the idmap hash from a call to classify
#
#----------------------------------------------------------------------------
sub fast_get_html_colored_message
{
    my ( $self, $session, $file, $matrix, $idmap ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    $self->{parser__}->{color__}        = $session;
    $self->{parser__}->{color_matrix__} = $matrix;
    $self->{parser__}->{color_idmap__}  = $idmap;
    $self->{parser__}->{color_userid__} = $userid;
    $self->{parser__}->{bayes__}        = bless $self;

    my $result = $self->{parser__}->parse_file( $file,   # PROFILE BLOCK START
            $self->global_config_( 'message_cutoff' ) ); # PROFILE BLOCK STOP

    $self->{parser__}->{color__} = '';

    return $result;
}

#----------------------------------------------------------------------------
#
# create_bucket
#
# Creates a new bucket, returns 1 if the creation succeeded
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      Name for the new bucket
#
#----------------------------------------------------------------------------
sub create_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( $self->is_bucket( $session, $bucket ) ||           # PROFILE BLOCK START
         $self->is_pseudo_bucket( $session, $bucket ) ) {   # PROFILE BLOCK STOP
        return 0;
    }

    return 0 if ( $bucket =~ /[^[:lower:]\-_0-9]/ );

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'insert into buckets ( name, pseudo, userid )
                      values (    ?,      0,      ? );',
        $bucket, $userid );                   # PROFILE BLOCK STOP
    $self->db_update_cache__( $session, $bucket );

    return 1;
}

#----------------------------------------------------------------------------
#
# delete_bucket
#
# Deletes a bucket, returns 1 if the delete succeeded
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      Name of the bucket to delete
#
#----------------------------------------------------------------------------
sub delete_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Make sure that the bucket passed in actually exists

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'delete from buckets
                where buckets.userid = ? and
                      buckets.name   = ? and
                      buckets.pseudo = 0;',
        $userid, $bucket );                   # PROFILE BLOCK STOP

    $self->db_update_cache__( $session, undef, $bucket );
    $self->{history__}->force_requery();

    return 1;
}

#----------------------------------------------------------------------------
#
# rename_bucket
#
# Renames a bucket, returns 1 if the rename succeeded
#
# $session             A valid session key returned by a call to get_session_key
# $old_bucket          The old name of the bucket
# $new_bucket          The new name of the bucket
#
#----------------------------------------------------------------------------
sub rename_bucket
{
    my ( $self, $session, $old_bucket, $new_bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Make sure that the bucket passed in actually exists

    if ( !defined( $self->{db_bucketid__}{$userid}{$old_bucket} ) ) {
        $self->log_( 0, "Bad bucket name $old_bucket to rename_bucket" );
        return 0;
    }

    if (  defined( $self->{db_bucketid__}{$userid}{$new_bucket} ) ) {
        $self->log_( 0, "Bucket named $new_bucket already exists" );
        return 0;
    }

    return 0 if ( $new_bucket =~ /[^[:lower:]\-_0-9]/ );

    my $id = $self->{db_bucketid__}{$userid}{$old_bucket}{id};

    $self->log_( 1, "Rename bucket $old_bucket to $new_bucket" );

    my $result = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'update buckets set name = ? where id = ?;',
        $new_bucket, $id );                                # PROFILE BLOCK STOP

    if ( !defined( $result ) || ( $result == -1 ) ) {
        return 0;
    } else {
        $self->db_update_cache__( $session, $new_bucket, $old_bucket );
        $self->{history__}->force_requery();

        return 1;
    }
}

#----------------------------------------------------------------------------
#
# add_messages_to_bucket
#
# Parses mail messages and updates the statistics in the specified bucket
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          Name of the bucket to be updated
# @files           List of file names to parse
#
#----------------------------------------------------------------------------
sub add_messages_to_bucket
{
    my ( $self, $session, $bucket, @files ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    # This is done to clear out the word list because in the loop
    # below we are going to not reset the word list on each parse

    $self->{parser__}->start_parse();
    $self->{parser__}->stop_parse();

    foreach my $file (@files) {
        $self->{parser__}->parse_file( $file,  # PROFILE BLOCK START
            $self->global_config_( 'message_cutoff' ),
            0 );  # PROFILE BLOCK STOP (Do not reset word list)
    }

    $self->add_words_to_bucket__( $session, $bucket, 1 );
    $self->db_update_cache__( $session, $bucket );

    return 1;
}

#----------------------------------------------------------------------------
#
# add_message_to_bucket
#
# Parses a mail message and updates the statistics in the specified bucket
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          Name of the bucket to be updated
# $file            Name of file containing mail message to parse
#
#----------------------------------------------------------------------------
sub add_message_to_bucket
{
    my ( $self, $session, $bucket, $file ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    return $self->add_messages_to_bucket( $session, $bucket, $file );
}

#----------------------------------------------------------------------------
#
# remove_message_from_bucket
#
# Parses a mail message and updates the statistics in the specified bucket
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          Name of the bucket to be updated
# $file            Name of file containing mail message to parse
#
#----------------------------------------------------------------------------
sub remove_message_from_bucket
{
    my ( $self, $session, $bucket, $file ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    $self->{parser__}->parse_file( $file,            # PROFILE BLOCK START
        $self->global_config_( 'message_cutoff' ) ); # PROFILE BLOCK STOP
    $self->add_words_to_bucket__( $session, $bucket, -1 );

    $self->db_update_cache__( $session, $bucket );

    return 1;
}

#----------------------------------------------------------------------------
#
# get_buckets_with_magnets
#
# Returns the names of the buckets for which magnets are defined
#
# $session     A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_buckets_with_magnets
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @result;

    $self->validate_sql_prepare_and_execute(               # PROFILE BLOCK START
        $self->{db_get_buckets_with_magnets__}, $userid ); # PROFILE BLOCK STOP
    while ( my $row = $self->{db_get_buckets_with_magnets__}->fetchrow_arrayref ) {
        push @result, ($row->[0]);
    }

    return @result;
}

#----------------------------------------------------------------------------
#
# get_magnet_types_in_bucket
#
# Returns the types of the magnets in a specific bucket
#
# $session     A valid session key returned by a call to get_session_key
# $bucket      The bucket to search for magnets
#
#----------------------------------------------------------------------------
sub get_magnet_types_in_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @result;

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return undef;
    }

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $h = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnet_types.mtype from magnet_types, magnets, buckets
                where magnet_types.id  = magnets.mtid and
                      magnets.bucketid = buckets.id and
                      buckets.id       = ?
                group by magnet_types.mtype
                order by magnet_types.mtype;',
        $bucketid );                                  # PROFILE BLOCK STOP

    while ( my $row = $h->fetchrow_arrayref ) {
        push @result, ($row->[0]);
    }
    $h->finish;

    return @result;
}

#----------------------------------------------------------------------------
#
# clear_bucket
#
# Removes all words from a bucket
#
# $session        A valid session key returned by a call to get_session_key
# $bucket         The bucket to clear
#
#----------------------------------------------------------------------------
sub clear_bucket
{
    my ( $self, $session, $bucket ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return undef;
    }

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'delete from matrix where matrix.bucketid = ?;',
        $bucketid );                          # PROFILE BLOCK STOP
    $self->db_update_cache__( $session, $bucket );

    return 1;
}

#----------------------------------------------------------------------------
#
# clear_magnets
#
# Removes every magnet currently defined
#
# $session     A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub clear_magnets
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    for my $bucket (keys %{$self->{db_bucketid__}{$userid}}) {
        my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
        $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
            'delete from magnets where magnets.bucketid = ?;',
            $bucketid );                          # PROFILE BLOCK STOP

        # Change status of the magnetized message in this bucket

        $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
            'update history set magnetid = 0
                    where bucketid = ? and
                          userid   = ?;',
            $bucketid, $userid );                 # PROFILE BLOCK STOP
    }

    return 1;
}

#----------------------------------------------------------------------------
#
# get_magnets
#
# Returns the magnets of a certain type in a bucket
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          The bucket to search for magnets
# $type            The magnet type (e.g. from, to or subject)
#
#----------------------------------------------------------------------------
sub get_magnets
{
    my ( $self, $session, $bucket, $type ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my @result;

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    return 0 if ( !defined( $type ) );

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $h = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnets.val from magnets, magnet_types
                where magnets.bucketid   = ? and
                      magnets.id        != 0 and
                      magnet_types.id    = magnets.mtid and
                      magnet_types.mtype = ?
                order by magnets.val;',
        $bucketid, $type );                           # PROFILE BLOCK STOP

    while ( my $row = $h->fetchrow_arrayref ) {
        push @result, ($row->[0]);
    }
    $h->finish;

    return @result;
}

#----------------------------------------------------------------------------
#
# create_magnet
#
# Make a new magnet
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          The bucket the magnet belongs in
# $type            The magnet type (e.g. from, to or subject)
# $text            The text of the magnet
#
#----------------------------------------------------------------------------
sub create_magnet
{
    my ( $self, $session, $bucket, $type, $text ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};
    my $result = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnet_types.id from magnet_types
                where magnet_types.mtype = ?;',
        $type )->fetchrow_arrayref;                        # PROFILE BLOCK STOP

    my $mtid = $result->[0];
    return 0 if ( !defined( $mtid ) );

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'insert into magnets ( bucketid, mtid, val )
                      values (        ?,    ?,   ? );',
        $bucketid, $mtid, $text );            # PROFILE BLOCK STOP

    return 1;
}

#----------------------------------------------------------------------------
#
# get_magnet_types
#
# Get a hash mapping magnet types (e.g. from) to magnet names (e.g. From);
#
# $session     A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_magnet_types
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my %result;

    my $h = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnet_types.mtype, magnet_types.header
                from magnet_types order by mtype;' ); # PROFILE BLOCK STOP

    while ( my $row = $h->fetchrow_arrayref ) {
        $result{$row->[0]} = $row->[1];
    }
    $h->finish;

    return %result;
}

#----------------------------------------------------------------------------
#
# delete_magnet
#
# Remove a magnet
#
# $session         A valid session key returned by a call to get_session_key
# $bucket          The bucket the magnet belongs in
# $type            The magnet type (e.g. from, to or subject)
# $text            The text of the magnet
#
#----------------------------------------------------------------------------
sub delete_magnet
{
    my ( $self, $session, $bucket, $type, $text ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    if ( !defined( $self->{db_bucketid__}{$userid}{$bucket} ) ) {
        return 0;
    }

    my $bucketid = $self->{db_bucketid__}{$userid}{$bucket}{id};

    my $result = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select magnets.id from magnets, magnet_types
                where magnets.mtid       = magnet_types.id and
                      magnets.bucketid   = ? and
                      magnets.val        = ? and
                      magnet_types.mtype = ?;',
        $bucketid, $text, $type )->fetchrow_arrayref;      # PROFILE BLOCK STOP

    return 0 if ( !defined( $result ) );

    my $magnetid = $result->[0];

    return 0 if ( !defined( $magnetid ) );

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'delete from magnets where id = ?;',
        $magnetid );                          # PROFILE BLOCK STOP

    # Change status of the magnetized message by this magnet

    $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'update history set magnetid = 0
                where magnetid = ? and
                      userid   = ?;',
        $magnetid, $userid );                 # PROFILE BLOCK STOP

    $self->{history__}->force_requery();

    return 1;
}

#----------------------------------------------------------------------------
#
# get_stopword_list
#
# Gets the complete list of stop words
#
# $session     A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub get_stopword_list
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    return $self->{parser__}->{mangle__}->stopwords();
}

#----------------------------------------------------------------------------
#
# magnet_count
#
# Gets the number of magnets that are defined
#
# $session     A valid session key returned by a call to get_session_key
#
#----------------------------------------------------------------------------
sub magnet_count
{
    my ( $self, $session ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    my $result = $self->validate_sql_prepare_and_execute(  # PROFILE BLOCK START
        'select count(*) from magnets, buckets
                where buckets.userid   = ? and
                      magnets.id      != 0 and
                      magnets.bucketid = buckets.id;',
        $userid )->fetchrow_arrayref;                      # PROFILE BLOCK STOP

    if ( defined( $result ) ) {
        return $result->[0];
    } else {
        return 0;
    }
}

#----------------------------------------------------------------------------
#
# add_stopword, remove_stopword
#
# Adds or removes a stop word
#
# $session     A valid session key returned by a call to get_session_key
# $stopword    The word to add or remove
#
# Return 0 for a bad stop word, and 1 otherwise
#
#----------------------------------------------------------------------------
sub add_stopword
{
    my ( $self, $session, $stopword ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Pass language parameter to add_stopword()

    return $self->{parser__}->{mangle__}->add_stopword(           # PROFILE BLOCK START
        $stopword, $self->module_config_( 'html', 'language' ) ); # PROFILE BLOCK STOP
}

sub remove_stopword
{
    my ( $self, $session, $stopword ) = @_;

    my $userid = $self->valid_session_key__( $session );
    return undef if ( !defined( $userid ) );

    # Pass language parameter to remove_stopword()

    return $self->{parser__}->{mangle__}->remove_stopword(        # PROFILE BLOCK START
        $stopword, $self->module_config_( 'html', 'language' ) ); # PROFILE BLOCK STOP
}


#----------------------------------------------------------------------------
#
# db_quote
#
# Quote a string for use in a sql statement. Before calling DBI::quote on the
# string the string is also checked for any null-bytes.
#
# $string   The string that should be quoted.
#
# returns the quoted string without any possible null-bytes
#----------------------------------------------------------------------------
sub db_quote {
    my $self   = shift;
    my $string = shift;

    my $backup = $string;
    if ( $string =~ s/\x00//g ) {
        my ( $package, $file, $line ) = caller;
        $self->log_( 0, "Found null-byte in string '$backup'. Called from package '$package' ($file), line $line." );
    }

    return $self->{db__}->quote( $string );
}


#----------------------------------------------------------------------------
#
# validate_sql_prepare_and_execute
#
# This method will prepare sql statements and execute them.
# The statement itself and any binding parameters are also
# tested for possible null-characters (\x00).
# If you pass in a handle to a prepared statement, the statement
# will be executed and possible binding-parameters are checked.
#
# $statement  The sql statement to prepare or the prepared statement handle
# @args       The (optional) list of binding parameters
#
# Returns the result of prepare()
#----------------------------------------------------------------------------
sub validate_sql_prepare_and_execute {
    my $self = shift;
    my $sql_or_sth  = shift;
    my @args = @_;

    my $dbh = $self->db();
    my $sth = undef;

    # Is this a statement-handle or a sql string?
    if ( (ref $sql_or_sth) =~ m/^DBI::/ ) {
        $sth = $sql_or_sth;
    }
    else {
        my $sql = $sql_or_sth;
        $sql = $self->check_for_nullbytes( $sql );
        $sth = $dbh->prepare( $sql );
    }

    my $execute_result = undef;

    # Any binding-params?
    if ( @args ) {
        foreach my $arg ( @args ) {
            $arg = $self->check_for_nullbytes( $arg );
        }
        $execute_result = $sth->execute( @args );
    }
    else {
        $execute_result = $sth->execute();
    }

    unless ( $execute_result ) {
        my ( $package, $file, $line ) = caller;
        $self->log_( 0, "DBI::execute failed.  Called from package '$package' ($file), line $line." );
    }

    return $sth;
}


#----------------------------------------------------------------------------
#
# check_for_nullbytes
#
# Will check a passed-in string for possible null-bytes and log and error
# message in case a null-byte is found.
#
# Will return the string with any null-bytes removed.
#----------------------------------------------------------------------------
sub check_for_nullbytes {
    my $self = shift;
    my $string = shift;

    if ( defined $string ) {
        my $backup = $string;

        if ( my $count = ( $string =~ s/\x00//g ) ) {
            my ( $package, $file, $line ) = caller( 1 );
            $self->log_( 0, "Found $count null-character(s) in string '$backup'. Called from package '$package' ($file), line $line." );
        }
    }

    return $string;
}

#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# _____   _____   _____  _______ _____        _______   _______  _____  _____
#|_____] |     | |_____] |______   |   |      |______   |_____| |_____]   |
#|       |_____| |       |       __|__ |_____ |______   |     | |       __|__
#
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

# GETTERS/SETTERS

sub wordscores
{
    my ( $self, $value ) = @_;

    $self->{wordscores__} = $value if (defined $value);
    return $self->{wordscores__};
}

sub wmformat
{
    my ( $self, $value ) = @_;

    $self->{wmformat__} = $value if (defined $value);
    return $self->{wmformat__};
}

sub db
{
    my ( $self ) = @_;

    return $self->{db__};
}

sub history
{
    my ( $self, $history ) = @_;

    $self->{history__} = $history;
}

1;

