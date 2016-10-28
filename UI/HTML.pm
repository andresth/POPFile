# POPFILE LOADABLE MODULE
package UI::HTML;

#----------------------------------------------------------------------------
#
# This package contains an HTML UI for POPFile
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
#----------------------------------------------------------------------------

use UI::HTTP;
@ISA = ("UI::HTTP");

use strict;
use warnings;
use locale;

use IO::Socket;
use IO::Select;
use Digest::MD5 qw( md5_hex );
use HTML::Template;
use Date::Format;

# A handy variable containing the value of an EOL for the network

my $eol = "\015\012";

# Constant used by the history deletion code

my $seconds_per_day = 60 * 60 * 24;

# These are used for Japanese support

# ASCII characters
my $ascii = '[\x00-\x7F]';

# EUC-JP 2 byte characters
my $two_bytes_euc_jp = '(?:[\x8E\xA1-\xFE][\xA1-\xFE])';

# EUC-JP 3 byte characters
my $three_bytes_euc_jp = '(?:\x8F[\xA1-\xFE][\xA1-\xFE])';

# EUC-JP characters
my $euc_jp = "(?:$ascii|$two_bytes_euc_jp|$three_bytes_euc_jp)";

my %headers_table = ( 'from',    'From',            # PROFILE BLOCK START
                      'to',      'To',
                      'cc',      'Cc',
                      'subject', 'Subject',
                      'date',    'Date',
                      'inserted', 'Arrived',
                      'size',    'Size',
                      'bucket',  'Classification'); # PROFILE BLOCK STOP


#----------------------------------------------------------------------------
# new
#
#   Class new() function
#----------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self = UI::HTTP->new();

    # The classifier (Classifier::Bayes)

    $self->{c__}      = 0;

    # Session key to make the UI safer

    $self->{session_key__}     = '';

    # The available skins

    $self->{skins__}           = ();

    # A hash containing a mapping between alphanumeric identifiers and
    # appropriate strings used for localization.  The string may
    # contain sprintf patterns for use in creating grammatically
    # correct strings, or simply be a string

    $self->{language__}        = {};

    # This is the list of available languages

    $self->{languages__} = ();

    # The last user to login via a proxy

    $self->{last_login__}      = '';

    # Used to determine whether the cache needs to be saved

    $self->{save_cache__}      = 0;

    # Stores a Classifier::Bayes session and is set up on the first UI
    # connection

    $self->{api_session__}     = '';

    # Must call bless before attempting to call any methods

    bless $self, $type;

    # This is the HTML module which we know as the HTML module

    $self->name( 'html' );

    return $self;
}

#----------------------------------------------------------------------------
#
# initialize
#
# Called to initialize the interface
#
#----------------------------------------------------------------------------
sub initialize
{
    my ( $self ) = @_;

    # The default listen port for the UI

    $self->config_( 'port', 8080 );

    # Sending of statistics is off

    $self->config_( 'send_stats', 0 );

    # The size of a history page

    $self->config_( 'page_size', 20 );

    # Only accept connections from the local machine for the UI

    $self->config_( 'local', 1 );

    # If no UI skin is specified use 'simplyblue' as the default

    $self->config_( 'skin', 'simplyblue' );

    # The user interface password

    $self->config_( 'password', md5_hex( '__popfile__' ) );

    # The last time (textual) that the statistics were reset

    my $lt = localtime;
    $self->config_( 'last_reset', $lt );

    # We start by assuming that the user speaks English like the
    # perfidious Anglo-Saxons that we are... :-)

    $self->config_( 'language', 'English' );

    # If this is 1 then when the language is loaded we will use the
    # language string identifier as the string shown in the UI.  This
    # is used to test whether which identifiers are used where.

    $self->config_( 'test_language', 0 );

    # This setting defines what is displayed in the word matrix:
    # 'freq' for frequencies, 'prob' for probabilities, 'score' for
    # logarithmic scores, if blank then the word table is not shown

    $self->config_( 'wordtable_format', '' );

    # Controls whether to cache templates or not

    $self->config_( 'cache_templates', 0 );

    # Controls whether or not we die if a template variable is missing
    # when we try to set it.  Setting it to 1 can be useful for
    # debugging purposes

    $self->config_( 'strict_templates', 0 );

    # The default columns to show in the History page.  The order here
    # is important, as is the presence of a + (show this column) or -
    # (hide this column) in the value.  By default we show everything

    $self->config_( 'columns',                                    # PROFILE BLOCK START
        '+inserted,+from,+to,-cc,+subject,-date,-size,+bucket' ); # PROFILE BLOCK STOP

    # An overriden date format set by the user, if empty then the
    # Locale_Date from the language file is used (see pretty_date__)

    $self->config_( 'date_format', '' );

    # If you want session dividers

    $self->config_( 'session_dividers', 1 );

    # The number of characters to show in each column in the history, if set
    # to 0 then POPFile tries to do this automatically

    $self->config_( 'column_characters', 0 );

    # Two variables that tell us whether to show help items
    # concerning bucket setup and training. The bucket item
    # is displayed by default, when it is turned off, the
    # training item is shown.

    $self->config_( 'show_training_help', 0 );
    $self->config_( 'show_bucket_help', 1 );

    # If you want to highlight active search or filter settings

    $self->config_( 'search_filter_highlight', 0 );

    # Load skins

    $self->load_skins__();

    # Load the list of available user interface languages

    $self->load_languages__();

    # Calculate a session key

    $self->change_session_key__();

    # The parent needs a reference to the url handler function

    $self->{url_handler_} = \&url_handler__;

    # Finally register for the messages that we need to receive

    $self->mq_register_( 'UIREG', $self );
    $self->mq_register_( 'LOGIN', $self );

    $self->calculate_today();

    return 1;
}

#----------------------------------------------------------------------------
#
# start
#
# Called to start the HTML interface running
#
#----------------------------------------------------------------------------
sub start
{
    my ( $self ) = @_;

    # In pre v0.21.0 POPFile the UI password was stored in plaintext
    # in the configuration data.  Check to see if the password is not
    # a hash and upgrade it automatically here.

    if ( length( $self->config_( 'password' ) ) != 32 ) {
        $self->config_( 'password',
             md5_hex( '__popfile__' . $self->config_( 'password' ) ) );
    }

    # Get a query session with the History object

    $self->{q__} = $self->{history__}->start_query();

    # Ensure that the messages subdirectory exists

    if ( !$self->{history__}->make_directory__(                          # PROFILE BLOCK START
        $self->get_user_path_( $self->global_config_( 'msgdir' ) ) ) ) { # PROFILE BLOCK STOP
        print STDERR "Failed to create the messages subdirectory\n";
        return 0;
    }

    # Load the current configuration from disk and then load up the
    # appropriate language, note that we always load English first so
    # that any extensions to the user interface that have not yet been
    # translated will still appear

    $self->load_language( 'English' );
    if ( $self->config_( 'language' ) ne 'English' ) {
        $self->load_language( $self->config_( 'language' ) );
    }

    # Set the classifier option wmformat__ according to our wordtable_format
    # option.

    $self->{c__}->wmformat( $self->config_( 'wordtable_format' ) );

    return $self->SUPER::start();
}

#----------------------------------------------------------------------------
#
# stop
#
# Called to stop the HTML interface running
#
#----------------------------------------------------------------------------
sub stop
{
    my ( $self ) = @_;

    if ( $self->{api_session__} ne '' ) {
        $self->{c__}->release_session_key( $self->{api_session__} );
    }

    $self->{history__}->stop_query( $self->{q__} );

    $self->SUPER::stop();
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

    # Handle registration of UI components

    if ( $type eq 'UIREG' ) {
        $self->register_configuration_item__( @message );
    }

    if ( $type eq 'LOGIN' ) {
        $self->{last_login__} = $message[0];
    }
}

#----------------------------------------------------------------------------
#
# url_handler__ - Handle a URL request
#
# $client     The web browser to send the results to
# $url        URL to process
# $command    The HTTP command used (GET or POST)
# $content    Any non-header data in the HTTP command
#
# Checks the session key and refuses access unless it matches.  Serves
# up a small set of specific urls that are the main UI pages and then
# any GIF file in the POPFile directory and CSS files in the skins
# subdirectory
#
#----------------------------------------------------------------------------
sub url_handler__
{
    my ( $self, $client, $url, $command, $content ) = @_;

    # Check to see if we obtained the session key yet
    if ( $self->{api_session__} eq '' ) {
        $self->{api_session__} = $self->{c__}->get_session_key(  # PROFILE BLOCK START
            'admin', '' );                                       # PROFILE BLOCK STOP
    }

    # See if there are any form parameters and if there are parse them
    # into the %form hash

    delete $self->{form_};

    # Remove a # element

    $url =~ s/#.*//;

    # If the URL was passed in through a GET then it may contain form
    # arguments separated by & signs, which we parse out into the
    # $self->{form_} where the key is the argument name and the value
    # the argument value, for example if you have foo=bar in the URL
    # then $self->{form_}{foo} is bar.

    if ( $command =~ /GET/i ) {
        if ( $url =~ s/\?(.*)// )  {
            $self->parse_form_( $1 );
        }
    }

    # If the URL was passed in through a POST then look for the POST data
    # and parse it filling the $self->{form_} in the same way as for GET
    # arguments

    if ( $command =~ /POST/i ) {
        $content =~ s/[\r\n]//g;
        $self->parse_form_( $content );
    }

    if ( $url =~ /\/autogen_(.+)\.bmp/ ) {
        $self->bmp_file__( $client, $1 );
        return 1;
    }

    if ( $url =~ /\/(.+\.gif)/ ) {
        $self->http_file_( $client, $self->get_root_path_( $1 ), 'image/gif' );
        return 1;
    }

    if ( $url =~ /\/(.+\.png)/ ) {
        $self->http_file_( $client, $self->get_root_path_( $1 ), 'image/png' );
        return 1;
    }

    if ( $url =~ /\/(.+\.ico)/ ) {
        $self->http_file_( $client, $self->get_root_path_( $1 ),  # PROFILE BLOCK START
             'image/x-icon' );                                    # PROFILE BLOCK STOP
        return 1;
    }

    if ( $url =~ /(skins\/.+\.css)/ ) {
        $self->http_file_( $client, $self->get_root_path_( $1 ), 'text/css' );
        return 1;
    }

    if ( $url =~ /(manual\/.+\.html)/ ) {
        $self->http_file_( $client, $self->get_root_path_( $1 ), 'text/html' );
        return 1;
    }

    # Check the password

    if ( $url eq '/password' )  {
        if ( defined( $self->{form_}{password} ) &&                  # PROFILE BLOCK START
             ( md5_hex( '__popfile__' . $self->{form_}{password} ) eq
               $self->config_( 'password' ) ) ) {                    # PROFILE BLOCK STOP
            $self->change_session_key__( $self );
            delete $self->{form_}{password};
            $self->{form_}{session} = $self->{session_key__};
            if ( defined( $self->{form_}{redirect} ) ) {
                $url = $self->{form_}{redirect};
                if ( $url =~ s/\?(.*)// )  {
                    $self->parse_form_( $1 );
                }
            }
        } else {
            $self->password_page( $client, defined( $self->{form_}{password} ), '/' );
            return 1;
        }
    }

    # If there's a password defined then check to see if the user
    # already knows the session key, if they don't then drop to the
    # password screen

    if ( ( (!defined($self->{form_}{session})) ||                           # PROFILE BLOCK START
           ($self->{form_}{session} eq '' ) ||
           ( $self->{form_}{session} ne $self->{session_key__} ) ) &&
           ( $self->config_( 'password' ) ne md5_hex( '__popfile__' ) ) ) { # PROFILE BLOCK STOP

        # Since the URL that has caused us to hit the password page
        # might have information stored in the form hash we need to
        # extract it out (except for the session key) and package it
        # up so that the password page can redirect to the right place
        # if the correct password is entered. This is especially
        # important for the XPL functionality.

        my $redirect_url = $url . '?';

        foreach my $k (keys %{$self->{form_}}) {

            # Skip the session key since we are in the process of
            # assigning a new one through the password page

            if ( $k ne 'session' ) {

                # If we are dealing with an array of values (see
                # parse_form_ for details) then we need to unpack it
                # into separate entries)

                if ( $k =~ /^(.+)_array$/ ) {
                    my $field = $1;

                    foreach my $v (@{$self->{form_}{$k}}) {
                        $redirect_url .= "$field=$v&"
                    }
                } else {
                    $redirect_url .= "$k=$self->{form_}{$k}&"
                }
            }
        }

        $redirect_url =~ s/&$//;

        $self->password_page( $client, 0, $redirect_url );

        return 1;
    }

    if ( $url eq '/jump_to_message' )  {
        $self->{form_}{filter}    = '';
        $self->{form_}{negate}    = '';
        $self->{form_}{search}    = '';
        $self->{form_}{setsearch} = 1;

        my $slot = $self->{form_}{view};

        if ( ( $slot =~ /^\d+$/ ) &&                            # PROFILE BLOCK START
             ( $self->{history__}->is_valid_slot( $slot ) ) ) { # PROFILE BLOCK STOP
            $self->http_redirect_( $client,                           # PROFILE BLOCK START
                 "/view?session=$self->{session_key__}&view=$slot" ); # PROFILE BLOCK STOP
        } else {
            $self->http_redirect_( $client, "/history" );
        }

        return 1;
    }

    if ( $url =~ /(popfile.*\.log)/ ) {
        $self->http_file_( $client, $self->logger()->debug_filename(),  # PROFILE BLOCK START
            'text/plain' );                                             # PROFILE BLOCK STOP
        return 1;
    }

    if ( ( defined($self->{form_}{session}) ) &&                   # PROFILE BLOCK START
         ( $self->{form_}{session} ne $self->{session_key__} ) ) { # PROFILE BLOCK STOP
        $self->session_page( $client, 0, $url );
        return 1;
    }

    if ( ( $url eq '/' ) || (!defined($self->{form_}{session})) ) {
        delete $self->{form_};
    }

    if ( $url eq '/shutdown' )  {
        my $text = $self->shutdown_page__();
        my $charset = $self->{language__}{LanguageCharset};

        my $http_header = $self->build_http_header_(
            200, "text/html; charset=$charset", 0, length( $text ) );

        if ( $client->connected ) {
            print $client $http_header . $text;
        }
        return 0;
    }

    # Watch out for clicks on the "Don't show me this again." buttons.
    # If that button is clicked for the bucket-setup item, we turn on
    # the training help item. And if this one is clicked away, both
    # will no longer be shown.

    if ( exists $self->{form_}{nomore_bucket_help} &&  # PROFILE BLOCK START
         $self->{form_}{nomore_bucket_help} ) {        # PROFILE BLOCK STOP
        $self->config_( 'show_bucket_help', 0 );
        $self->config_( 'show_training_help', 1 );
    }

    if ( exists $self->{form_}{nomore_training_help} &&  # PROFILE BLOCK START
         $self->{form_}{nomore_training_help} ) {        # PROFILE BLOCK STOP
        $self->config_( 'show_training_help', 0 );
    }

    # The url table maps URLs that we might receive to pages that we
    # display, the page table maps the pages to the functions that
    # handle them and the related template

    my %page_table = (                                              # PROFILE BLOCK START
        'security'      =>
            [ \&security_page,      'security-page.thtml'      ],
        'configuration' =>
            [ \&configuration_page, 'configuration-page.thtml' ],
        'buckets'       =>
            [ \&corpus_page,        'corpus-page.thtml'        ],
        'magnets'       =>
            [ \&magnet_page,        'magnet-page.thtml'        ],
        'advanced'      =>
            [ \&advanced_page,      'advanced-page.thtml'      ],
        'history'       =>
            [ \&history_page,       'history-page.thtml'       ],
        'view'          =>
            [ \&view_page,          'view-page.thtml'          ] ); # PROFILE BLOCK STOP

    my %url_table = ( '/security'      => 'security',       # PROFILE BLOCK START
                      '/configuration' => 'configuration',
                      '/buckets'       => 'buckets',
                      '/magnets'       => 'magnets',
                      '/advanced'      => 'advanced',
                      '/view'          => 'view',
                      '/history'       => 'history',
                      '/'              => 'history' );      # PROFILE BLOCK STOP

    # Any of the standard pages can be found in the url_table, the
    # other pages are probably files on disk

    if ( defined($url_table{$url}) )  {
        my ( $method, $template ) = @{$page_table{$url_table{$url}}};

        if ( !defined( $self->{api_session__} ) ) {
            $self->http_error_( $client, 500 );
            return;
        }

        &{$method}( $self, $client, $self->load_template__( $template ) );
        return 1;
    }

    $self->http_error_( $client, 404 );
    return 1;
}

#---------------------------------------------------------------------------
#
# bmp_file__ - Sends a 1x1 bitmap of a specific color to the browser
#
# $client    The web browser to send result to
# $color     An HTML color (hex or named)
#
#----------------------------------------------------------------------------
sub bmp_file__
{
    my ( $self, $client, $color ) = @_;

    $color = lc($color);

    # TODO: this is dirty something higher up (HTTP) should be
    # decoding the URL

    $color =~ s/^%23//; # if we have an prefixed hex color value,
                        # just dump the encoded hash-mark (#)

    # If the color contains something other than hex then do a map
    # on it first and then get the hex color, from the hex color
    # create a BMP file and return it

    if ( $color !~ /^[0-9a-f]{6}$/ ) {
        $color = $self->{c__}->{parser__}->map_color( $color );
    }

    if ( $color =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/ ) {
        my $bmp = '424d3a0000000000000036000000280000000100000001000000010018000000000004000000eb0a0000eb0a00000000000000000000' . "$3$2$1" . '00';
        my $file = '';
        for my $i (0..length($bmp)/2-1) {
            $file .= chr(hex(substr($bmp,$i*2,2)));
        }

        my $http_header = $self->build_http_header_( 200, "image/bmp", 0,
                                                     length( $file ) );

        if ( $client->connected ) {
            print $client $http_header . $file;
        }
        return 0;
    } else {
        return $self->http_error_( $client, 404 );
    }
}

#---------------------------------------------------------------------------
#
# http_ok - Output a standard HTTP 200 message with a body of data
# from a template
#
# $client    The web browser to send result to
# $templ     The template for the page to return
# $selected  Which tab is to be selected
#
#----------------------------------------------------------------------------
sub http_ok
{
    my ( $self, $client, $templ, $selected ) = @_;

    $selected = -1 if ( !defined( $selected ) );

    my @tab = ( 'menuStandard', 'menuStandard', 'menuStandard', 'menuStandard', 'menuStandard', 'menuStandard' );
    $tab[$selected] = 'menuSelected' if ( ( $selected <= $#tab ) &&  # PROFILE BLOCK START
                                          ( $selected >= 0 ) );      # PROFILE BLOCK STOP

    for my $i (0..$#tab) {
        $templ->param( "Common_Middle_Tab$i" => $tab[$i] );
    }

    my $update_check = '';

    # Check to see if we've checked for updates today.  If we have not
    # then insert a reference to an image that is generated through a
    # CGI.  Also send stats to the same site if that is allowed.

    if ( $self->{today__} ne $self->global_config_( 'last_update_check' ) ) {
        $self->calculate_today();

        if ( $self->global_config_( 'update_check' ) ) {
            my ( $major_version, $minor_version, $build_version ) =  # PROFILE BLOCK START
                $self->version() =~ /^v([^.]*)\.([^.]*)\.(.*)$/;     # PROFILE BLOCK STOP
            $templ->param( 'Common_Middle_If_UpdateCheck' => 1 );
            $templ->param( 'Common_Middle_Major_Version' => $major_version );
            $templ->param( 'Common_Middle_Minor_Version' => $minor_version );
            $templ->param( 'Common_Middle_Build_Version' => $build_version );
        }

        if ( $self->config_( 'send_stats' ) ) {
            $templ->param( 'Common_Middle_If_SendStats' => 1 );
            my @buckets = $self->{c__}->get_buckets(  # PROFILE BLOCK START
                $self->{api_session__} );             # PROFILE BLOCK STOP
            my $bc      = $#buckets + 1;
            $templ->param( 'Common_Middle_Buckets'  => $bc );
            $templ->param( 'Common_Middle_Messages' => $self->mcount__() );
            $templ->param( 'Common_Middle_Errors'   => $self->ecount__() );
        }

        $self->global_config_( 'last_update_check', $self->{today__}, 1 );
    }

    # Build an HTTP header for standard HTML

    my $charset = $self->{language__}{LanguageCharset};
    my $text = $templ->output;

    my $http_header = $self->build_http_header_(
        200, "text/html; charset=$charset", 0, length( $text ) );

    if ( $client->connected ) {
        $client->print( $http_header . $text );
    }
}

#----------------------------------------------------------------------------
#
# configuration_page - get the configuration options
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub configuration_page
{
    my ( $self, $client, $templ ) = @_;

    if ( defined($self->{form_}{skin}) ) {
        $self->config_( 'skin', $self->{form_}{skin} );
        $templ = $self->load_template__( 'configuration-page.thtml' );
    }

   if ( ( defined($self->{form_}{debug}) ) &&  # PROFILE BLOCK START
        ( ( $self->{form_}{debug} >= 1 ) &&
        ( $self->{form_}{debug} <= 4 ) ) ) {   # PROFILE BLOCK STOP
       $self->global_config_( 'debug', $self->{form_}{debug}-1 );
   }

    if ( defined($self->{form_}{language}) ) {
        if ( $self->config_( 'language' ) ne $self->{form_}{language} ) {
            $self->config_( 'language', $self->{form_}{language} );
            if ( $self->config_( 'language' ) ne 'English' ) {
                $self->load_language( 'English' );
            }
            $self->load_language( $self->config_( 'language' ) );

            # Force a template relocalization because the language has been
            # changed which changes the localization of the template

            $self->localize_template__( $templ );
        }
    }

    # Load all of the templates that are needed for the dynamic parts of
    # the configuration page, and for each one call its validation interface
    # so that any error messages or informational messages are fixed up
    # first

    my %dynamic_templates;

    for my $name (keys %{$self->{dynamic_ui__}{configuration}}) {
        $dynamic_templates{$name} = $self->load_template__(          # PROFILE BLOCK START
            $self->{dynamic_ui__}{configuration}{$name}{template} ); # PROFILE BLOCK STOP
        $self->{dynamic_ui__}{configuration}{$name}{object}->validate_item(  # PROFILE BLOCK START
            $name,
            $dynamic_templates{$name},
            \%{$self->{language__}},
            \%{$self->{form_}} );                                            # PROFILE BLOCK STOP
    }

    if ( defined($self->{form_}{ui_port}) ) {
        if ( ( $self->{form_}{ui_port} >= 1 ) &&  # PROFILE BLOCK START
             ( $self->{form_}{ui_port} < 65536 ) &&
             ( $self->module_config_( 'pop3', 'port' ) ne $self->{form_}{ui_port} )
            ) {                                   # PROFILE BLOCK STOP
            $self->config_( 'port', $self->{form_}{ui_port} );
        } else {
            if ( ( $self->module_config_( 'pop3', 'port' ) ne $self->{form_}{ui_port} ) ) {
              $templ->param( 'Configuration_If_UI_Port_Error' => 1 );
            } else {
              $templ->param( 'Configuration_If_UI_POP3_Port_Error' => 1 );
            }
            delete $self->{form_}{ui_port};
        }
    }

    if ( defined($self->{form_}{ui_port} ) ) {
        $templ->param( 'Configuration_UI_Port_Updated' =>  # PROFILE BLOCK START
            sprintf( $self->{language__}{Configuration_UIUpdate},
                $self->config_( 'port' ) ) );              # PROFILE BLOCK STOP
    }
    $templ->param( 'Configuration_UI_Port' => $self->config_( 'port' ) );

    if ( defined($self->{form_}{page_size}) ) {
        if ( ( $self->{form_}{page_size} >= 1 ) &&     # PROFILE BLOCK START
             ( $self->{form_}{page_size} <= 1000 ) ) { # PROFILE BLOCK STOP
            $self->config_( 'page_size', $self->{form_}{page_size} );
        } else {
            $templ->param( 'Configuration_If_Page_Size_Error' => 1 );
            delete $self->{form_}{page_size};
        }
    }

    if ( defined($self->{form_}{page_size} ) ) {
        $templ->param( 'Configuration_Page_Size_Updated' =>  # PROFILE BLOCK START
            sprintf( $self->{language__}{Configuration_HistoryUpdate},
                $self->config_( 'page_size' ) ) )            # PROFILE BLOCK STOP
    }
    $templ->param( 'Configuration_Page_Size' =>
        $self->config_( 'page_size' ) );

    if ( defined($self->{form_}{history_days}) ) {
        if ( ( $self->{form_}{history_days} >= 1 ) &&    # PROFILE BLOCK START
             ( $self->{form_}{history_days} <= 366 ) ) { # PROFILE BLOCK STOP
            $self->module_config_( 'history', 'history_days',  # PROFILE BLOCK START
                $self->{form_}{history_days} );                # PROFILE BLOCK STOP
        } else {
            $templ->param( 'Configuration_If_History_Days_Error' => 1 );
            delete $self->{form_}{history_days};
        }

        if ( defined( $self->{form_}{purge_history} ) ) {
             $self->{history__}->cleanup_history();
        }
    }

    $templ->param( 'Configuration_History_Days_Updated' => sprintf( $self->{language__}{Configuration_DaysUpdate}, $self->module_config_( 'history', 'history_days' ) ) ) if ( defined($self->{form_}{history_days} ) );
    $templ->param( 'Configuration_History_Days' => $self->module_config_( 'history', 'history_days' ) );

    if ( defined($self->{form_}{timeout}) ) {
        if ( ( $self->{form_}{timeout} >= 10 ) && ( $self->{form_}{timeout} <= 1800 ) ) {
            $self->global_config_( 'timeout', $self->{form_}{timeout} );
        } else {
            $templ->param( 'Configuration_If_TCP_Timeout_Error' => 1 );
            delete $self->{form_}{timeout};
        }
    }

    $templ->param( 'Configuration_TCP_Timeout_Updated' => sprintf( $self->{language__}{Configuration_TCPTimeoutUpdate}, $self->global_config_( 'timeout' ) ) ) if ( defined($self->{form_}{timeout} ) );
    $templ->param( 'Configuration_TCP_Timeout' => $self->global_config_( 'timeout' ) );

    if ( defined( $self->{form_}{update_fields} ) ) {
        my @columns = split(',', $self->config_( 'columns' ));
        my $new_columns = '';
        foreach my $column (@columns) {
            $column =~ s/^(\+|\-)//;
            if ( defined($self->{form_}{$column})) {
                $new_columns .= '+';
            } else {
                $new_columns .= '-';
            }
            $new_columns .= $column;
            $new_columns .= ',';
        }
        $self->config_( 'columns', $new_columns );
    }

    my ( @general_skins, @small_skins, @tiny_skins );
    for my $i (0..$#{$self->{skins__}}) {
        my %row_data;
        my $type = 'General';
        my $list = \@general_skins;
        my $name = $self->{skins__}[$i];
        $name =~ /\/([^\/]+)\/$/;
        $name = $1;
        my $selected = ( $name eq $self->config_( 'skin' ) )?'selected':'';

        if ( $name =~ /tiny/ ) {
            $type = 'Tiny';
            $list = \@tiny_skins;
        } else {
            if ( $name =~ /small/ ) {
                $type = 'Small';
                $list = \@small_skins;
            }
        }

        $row_data{"Configuration_$type" . '_Skin'}     = $name;
        $row_data{"Configuration_$type" . '_Selected'} = $selected;

        push ( @$list, \%row_data );
    }
    $templ->param( "Configuration_Loop_General_Skins", \@general_skins );
    $templ->param( "Configuration_Loop_Small_Skins",   \@small_skins   );
    $templ->param( "Configuration_Loop_Tiny_Skins",    \@tiny_skins    );

    my @language_loop;
    foreach my $lang (@{$self->{languages__}}) {
        my %row_data;
        $row_data{Configuration_Language} = $lang;
        $row_data{Configuration_Selected_Language} = ( $lang eq $self->config_( 'language' ) )?'selected':'';
        push ( @language_loop, \%row_data );
    }
    $templ->param( 'Configuration_Loop_Languages' => \@language_loop );

    my @columns = split(',', $self->config_( 'columns' ));
    my @column_data;
    foreach my $column (@columns) {
        my %row;
        $column =~ /(\+|\-)/;
        my $selected = ($1 eq '+')?'checked':'';
        $column =~ s/^.//;
        $row{Configuration_Field_Name} = $column;
        $row{Configuration_Localized_Field_Name} =        # PROFILE BLOCK START
            $self->{language__}{$headers_table{$column}}; # PROFILE BLOCK STOP
        $row{Configuration_Field_Value} = $selected;
        push ( @column_data, \%row );
    }
    $templ->param( 'Configuration_Loop_History_Columns' => \@column_data );

    # Insert all the items that are dynamically created from the
    # modules that are loaded

    my $configuration_html = '';
    my $last_module = '';
    for my $name (sort keys %{$self->{dynamic_ui__}{configuration}}) {
        $name =~ /^([^_]+)_/;
        my $module = $1;
        if ( $last_module ne $module ) {
            $last_module = $module;
            $configuration_html .= "<hr>\n<h2 class=\"configuration\">";
            $configuration_html .= uc($module);
            $configuration_html .= "</h2>\n";
        }
        $self->{dynamic_ui__}{configuration}{$name}{object}->configure_item(
            $name, $dynamic_templates{$name}, \%{$self->{language__}} );
        $configuration_html .= $dynamic_templates{$name}->output;
    }

    $templ->param( 'Configuration_Dynamic' => $configuration_html );
    $templ->param( 'Configuration_Debug_' . ( $self->global_config_( 'debug' ) + 1 ) . '_Selected' => 'selected' );

    if ( $self->global_config_( 'debug' ) & 1 ) {
        $templ->param( 'Configuration_If_Show_Log' => 1 );
    }

    $self->http_ok( $client, $templ, 3 );
}

#----------------------------------------------------------------------------
#
# security_page - get the security configuration page
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub security_page
{
    my ( $self, $client, $templ ) = @_;

    my $server_error = '';
    my $port_error   = '';

    if ( ( defined($self->{form_}{password}) ) &&                         # PROFILE BLOCK START
         ( $self->{form_}{password} ne $self->config_( 'password' ) ) ) { # PROFILE BLOCK STOP
        $self->config_( 'password', md5_hex( '__popfile__' . $self->{form_}{password} ) )
    }
    $self->config_( 'local', $self->{form_}{localui}-1 )      if ( defined($self->{form_}{localui}) );
    $self->global_config_( 'update_check', $self->{form_}{update_check}-1 ) if ( defined($self->{form_}{update_check}) );
    $self->config_( 'send_stats', $self->{form_}{send_stats}-1 )   if ( defined($self->{form_}{send_stats}) );

    $templ->param( 'Security_If_Local' => ( $self->config_( 'local' ) == 1 ) );
    $templ->param( 'Security_Password' => ( $self->config_( 'password' ) eq md5_hex( '__popfile__' ) )?'':$self->config_( 'password' ) );
    $templ->param( 'Security_If_Password_Updated' => ( defined($self->{form_}{password} ) ) );
    $templ->param( 'Security_If_Update_Check' => ( $self->global_config_( 'update_check' ) == 1 ) );
    $templ->param( 'Security_If_Send_Stats' => ( $self->config_( 'send_stats' ) == 1 ) );

    my %security_templates;

    for my $name (keys %{$self->{dynamic_ui__}{security}}) {
        $security_templates{$name} = $self->load_template__(    # PROFILE BLOCK START
            $self->{dynamic_ui__}{security}{$name}{template} ); # PROFILE BLOCK STOP
        $self->{dynamic_ui__}{security}{$name}{object}->validate_item(  # PROFILE BLOCK START
            $name,
            $security_templates{$name},
            \%{$self->{language__}},
            \%{$self->{form_}} );                                       # PROFILE BLOCK STOP
    }

    my %chain_templates;

    for my $name (keys %{$self->{dynamic_ui__}{chain}}) {
        $chain_templates{$name} = $self->load_template__(    # PROFILE BLOCK START
            $self->{dynamic_ui__}{chain}{$name}{template} ); # PROFILE BLOCK STOP
        $self->{dynamic_ui__}{chain}{$name}{object}->validate_item(  # PROFILE BLOCK START
            $name,
            $chain_templates{$name},
            \%{$self->{language__}},
            \%{$self->{form_}} );                                    # PROFILE BLOCK STOP
    }

    my $security_html = '';

    for my $name (sort keys %{$self->{dynamic_ui__}{security}}) {
        $self->{dynamic_ui__}{security}{$name}{object}->configure_item(  # PROFILE BLOCK START
            $name,
            $security_templates{$name},
            \%{$self->{language__}} );                                   # PROFILE BLOCK STOP
        $security_html .= $security_templates{$name}->output;
    }

    my $chain_html = '';

    for my $name (sort keys %{$self->{dynamic_ui__}{chain}}) {
        $self->{dynamic_ui__}{chain}{$name}{object}->configure_item( # PROFILE BLOCK START
            $name,
            $chain_templates{$name},
            \%{$self->{language__}} );                               # PROFILE BLOCK STOP
        $chain_html .= $chain_templates{$name}->output;
    }

    $templ->param( 'Security_Dynamic_Security' => $security_html );
    $templ->param( 'Security_Dynamic_Chain'    => $chain_html    );

    $self->http_ok( $client,$templ, 4 );
}

#----------------------------------------------------------------------------
#
# pretty_number - format a number with ,s every 1000
#
# $number       The number to format
#
#----------------------------------------------------------------------------
sub pretty_number
{
    my ( $self, $number ) = @_;

    my $c = reverse $self->{language__}{Locale_Thousands};

    $number = reverse $number;
    $number =~ s/(\d{3})/$1$c/g;
    $number = reverse $number;
    $c =~ s/\./\\./g;
    $number =~ s/^$c(.*)/$1/;

    return $number;
}

#----------------------------------------------------------------------------
#
# pretty_date__ - format a date as the user wants to see it
#
# $date           Epoch seconds
# $long           Set to 1 if you want only the long date option
#
#----------------------------------------------------------------------------
sub pretty_date__
{
    my ( $self, $date, $long ) = @_;

    $long = 0 if ( !defined( $long ) );
    my $format = $self->config_( 'date_format' );

    if ( $format eq '' ) {
        $format = $self->{language__}{Locale_Date};
    }

    if ( $format =~ /[\t ]*(.+)[\t ]*\|[\t ]*(.+)/ ) {
        if ( ( $date < time ) &&                             # PROFILE BLOCK START
             ( $date > ( time - ( 7 * 24 * 60 * 60 ) ) ) ) { # PROFILE BLOCK STOP
            if ( $long ) {
                return time2str( $2, $date );
            } else {
                return time2str( $1, $date );
            }
        } else {
            return time2str( $2, $date );
        }
    } else {
        return time2str( $format, $date );
    }
}

#----------------------------------------------------------------------------
#
# advanced_page - very advanced configuration options
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub advanced_page
{
    use Cwd 'abs_path';

    my ( $self, $client, $templ ) = @_;

    # Handle updating the parameter table

    if ( defined( $self->{form_}{update_params} ) ) {
        foreach my $param (sort keys %{$self->{form_}}) {
            if ( $param =~ /parameter_(.*)/ ) {
                $self->{configuration__}->parameter( $1,  # PROFILE BLOCK START
                    $self->{form_}{$param} );             # PROFILE BLOCK STOP
            }
        }

        $self->{configuration__}->save_configuration();
    }

    # Handle adding/removing words to/from stopwords

    if ( defined($self->{form_}{newword}) ) {
        my $result = $self->{c__}->add_stopword( $self->{api_session__},  # PROFILE BLOCK START
                         $self->{form_}{newword} );                       # PROFILE BLOCK STOP
        if ( $result == 0 ) {
            $templ->param( 'Advanced_If_Add_Message' => 1 );
        }
    }

    if ( defined($self->{form_}{word}) ) {
        my $result = $self->{c__}->remove_stopword( $self->{api_session__},  # PROFILE BLOCK START
                         $self->{form_}{word} );                             # PROFILE BLOCK STOP
        if ( $result == 0 ) {
            $templ->param( 'Advanced_If_Delete_Message' => 1 );
        }
    }

    # the word census ( stopwords )

    my $last = '';
    my $need_comma = 0;
    my $groupCounter = 0;
    my $groupSize = 5;
    my @words = $self->{c__}->get_stopword_list( $self->{api_session__} );
    my $commas;

    my @word_loop;
    my $c;
    @words = sort @words;
    push ( @words, ' ' );
    for my $word (@words) {
        if ( $self->config_( 'language' ) =~ /^Korean$/ ) {
            $word =~ /^(.)/;
            $c = $1;
        } else {
            if ( $self->config_( 'language' ) =~ /^Nihongo$/ ) {
                $word =~ /^($euc_jp)/o;
                $c = $1;
            } else {
                $word =~ /^(.)/;
                $c = $1;
            }
        }

        $last = $c if ( $last eq '' );

        if ( $c ne $last ) {
            my %row_data;
            $row_data{Advanced_Words} = $commas;
            $commas = '';

            if ( $groupCounter == $groupSize ) {
                $row_data{Advanced_Row_Class} = 'advancedAlphabetGroupSpacing';
            } else {
                $row_data{Advanced_Row_Class} = 'advancedAlphabet';
            }
            $row_data{Advanced_Character} = $last;

            if ( $groupCounter == $groupSize ) {
                $row_data{Advanced_Word_Class} = 'advancedWordsGroupSpacing';
                $groupCounter = 0;
            } else {
                $row_data{Advanced_Word_Class} = 'advancedWords';
            }
            $last = $c;
            $need_comma = 0;
            $groupCounter += 1;
            push ( @word_loop, \%row_data );
        }

        if ( $need_comma == 1 ) {
            $commas .= ", $word";
        } else {
            $commas .= $word;
            $need_comma = 1;
        }
    }

    $templ->param( 'Advanced_Loop_Word' => \@word_loop );

    my $config_file = $self->get_user_path_( 'popfile.cfg' );
    if ( -e $config_file ) {
        $config_file = abs_path( $config_file );
    }

    if ( ( $^O eq 'MSWin32' ) &&                           # PROFILE BLOCK START
         ( $self->config_( 'language' ) eq 'Nihongo' ) ) { # PROFILE BLOCK STOP

        # Converts configuration file path to LanguageCharset

        require Encode;
        require File::Glob::Windows;

        Encode::from_to( $config_file,                           # PROFILE BLOCK START
                         File::Glob::Windows::getCodePage(),
                         $self->{language__}{LanguageCharset} ); # PROFILE BLOCK STOP
    }

    $templ->param( 'Advanced_POPFILE_CFG' => $config_file );

    # POPFile global parameters

    my $last_module = '';

    my @param_loop;
    foreach my $param ($self->{configuration__}->configuration_parameters()) {
        my $value = $self->{configuration__}->parameter( $param );
        $param =~ /^([^_]+)_/;

        my %row_data;

        if ( ( $last_module ne '' ) && ( $last_module ne $1 ) ) {
            $row_data{Advanced_If_New_Module} = 1;
        } else {
            $row_data{Advanced_If_New_Module} = 0;
        }

        $last_module = $1;

        $row_data{Advanced_Parameter}   = $param;
        $row_data{Advanced_Value}       = $value;
        $row_data{Advanced_If_Changed}  =                    # PROFILE BLOCK START
            !$self->{configuration__}->is_default( $param ); # PROFILE BLOCK STOP
        $row_data{Advanced_If_Password} =                    # PROFILE BLOCK START
            ( $param =~ /_password/ ) ? 1 : 0;               # PROFILE BLOCK STOP


        push ( @param_loop, \%row_data);
    }

    $templ->param( 'Advanced_Loop_Parameter' => \@param_loop );

    $self->http_ok( $client, $templ, 5 );
}

sub max
{
    my ( $a, $b ) = @_;

    return ( $a > $b )?$a:$b;
}

#----------------------------------------------------------------------------
#
# magnet_page - the list of bucket magnets
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub magnet_page
{
    my ( $self, $client, $templ ) = @_;

    my @messages = ();

    if ( defined( $self->{form_}{delete} ) ) {
        for my $i ( 1 .. $self->{form_}{count} ) {
            if ( defined( $self->{form_}{"remove$i"} ) &&  # PROFILE BLOCK START
               ( $self->{form_}{"remove$i"} ) ) {          # PROFILE BLOCK STOP
                my $mtype   = $self->{form_}{"type$i"};
                my $mtext   = $self->{form_}{"text$i"};
                my $mbucket = $self->{form_}{"bucket$i"};

                $self->{c__}->delete_magnet( $self->{api_session__}, $mbucket, $mtype, $mtext );
            }
        }
    }

    if ( defined( $self->{form_}{count} ) &&     # PROFILE BLOCK START
       ( defined( $self->{form_}{update} ) ||
         defined( $self->{form_}{create} ) ) ) { # PROFILE BLOCK STOP
        for my $i ( 0 .. $self->{form_}{count} ) {
            my $mtype   = $self->{form_}{"type$i"};
            my $mtext   = $self->{form_}{"text$i"};
            my $mbucket = $self->{form_}{"bucket$i"};

            if ( defined( $self->{form_}{update} ) ) {
                my $otype   = $self->{form_}{"otype$i"};
                my $otext   = $self->{form_}{"otext$i"};
                my $obucket = $self->{form_}{"obucket$i"};

                if ( defined( $otype ) ) {
                    $self->{c__}->delete_magnet( $self->{api_session__},  # PROFILE BLOCK START
                        $obucket, $otype, $otext );                       # PROFILE BLOCK STOP
                }
            }

            if ( ( defined($mbucket) ) &&  # PROFILE BLOCK START
                 ( $mbucket ne '' ) &&
                 ( $mtext ne '' ) ) {      # PROFILE BLOCK STOP

                # Support for feature request 77646 - import function.
                # goal is a method of creating multiple magnets all
                # with the same target bucket quickly.
                #
                # If we have multiple lines in $mtext, each line will
                # actually be used to create a new magnet all with the
                # same target.  We loop through all of the requested
                # magnets, check to make sure they are all valid (not
                # already existing, etc...) and then loop through them
                # again to create them.  this way, if even one isn't
                # valid, none will be created.
                #
                # We also get rid of an \r's that may have been passed
                # in.  We also and ignore lines containing, only white
                # space and if a line is repeated we add just one
                # bucket for it.

                $mtext =~ s/\r\n/\n/g;

                my @all_mtexts = split(/\n/,$mtext);
                my %mtext_hash;
                @mtext_hash{@all_mtexts} = ();
                my @mtexts = keys %mtext_hash;
                my $found = 0;
                my %row_data;

                foreach my $current_mtext (@mtexts) {
                    for my $bucket ($self->{c__}->get_buckets_with_magnets(   # PROFILE BLOCK START
                                        $self->{api_session__} )) {           # PROFILE BLOCK STOP
                        my %magnets;
                        @magnets{ $self->{c__}->get_magnets(  # PROFILE BLOCK START
                                      $self->{api_session__},
                                      $bucket,
                                      $mtype )} = ();         # PROFILE BLOCK STOP

                        if ( exists( $magnets{$current_mtext} ) ) {
                            $found  = 1;
                            $row_data{Magnet_Message} =                      # PROFILE BLOCK START
                                sprintf( $self->{language__}{Magnet_Error1},
                                         "$mtype: $current_mtext",
                                         $bucket );                          # PROFILE BLOCK STOP
                            push( @messages, \%row_data );
                            last;
                        }
                    }

                    if ( $found == 0 )  {
                        for my $bucket ($self->{c__}->get_buckets_with_magnets( $self->{api_session__} )) {
                            my %magnets;
                            @magnets{ $self->{c__}->get_magnets( $self->{api_session__}, $bucket, $mtype )} = ();

                            for my $from (keys %magnets)  {
                                if ( ( $self->{c__}->single_magnet_match( $mtext,  $from, $mtype ) ) ||   # PROFILE BLOCK START
                                     ( $self->{c__}->single_magnet_match(  $from, $mtext, $mtype ) ) ) {  # PROFILE BLOCK STOP
                                    $found = 1;
                                    $row_data{Magnet_Message} =               # PROFILE BLOCK START
                                        sprintf( $self->{language__}{Magnet_Error2},
                                                 "$mtype: $current_mtext",
                                                 "$mtype: $from",
                                                 $bucket );                   # PROFILE BLOCK STOP
                                    push( @messages, \%row_data );
                                    last;
                                }
                            }
                        }
                    }
                }

                if ( $found == 0 ) {
                    foreach my $current_mtext (@mtexts) {

                        # Skip magnet definition if it consists only of
                        # white spaces

                        if ( $current_mtext =~ /^[ \t]*$/ ) {
                            next;
                        }

                        # It is possible to type leading or trailing white
                        # space in a magnet definition which can later
                        # cause mysterious failures because the whitespace
                        # is eaten by the browser when the magnet is
                        # displayed but is matched in the regular
                        # expression that does the magnet matching and
                        # will cause failures... so strip off the
                        # whitespace

                        $current_mtext =~ s/^[ \t]+//;
                        $current_mtext =~ s/[ \t]+$//;

                        $self->{c__}->create_magnet( $self->{api_session__}, $mbucket, $mtype, $current_mtext );
                        if ( !defined( $self->{form_}{update} ) ) {
                            $row_data{Magnet_Message} =                      # PROFILE BLOCK START
                                sprintf( $self->{language__}{Magnet_Error3},
                                         "$mtype: $current_mtext",
                                         $mbucket );                         # PROFILE BLOCK STOP
                            push( @messages, \%row_data );
                        }
                    }
                }
            }
        }
    }

    if ( scalar @messages > 0 ) {
        $templ->param( 'Magnet_If_Message' => 1 );
        $templ->param( 'Magnet_Loop_Messages' => \@messages );
    }

    # Current Magnets panel

    my $start_magnet = $self->{form_}{start_magnet};
    my $stop_magnet  = $self->{form_}{stop_magnet};
    my $magnet_count = $self->{c__}->magnet_count( $self->{api_session__} );
    my $navigator = '';

    if ( !defined( $start_magnet ) ) {
        $start_magnet = 0;
    }

    if ( !defined( $stop_magnet ) ) {
        $stop_magnet = $start_magnet + $self->config_( 'page_size' ) - 1;
    }

    if ( $self->config_( 'page_size' ) < $magnet_count ) {
        $self->set_magnet_navigator__( $templ, $start_magnet,  # PROFILE BLOCK START
            $stop_magnet, $magnet_count );                     # PROFILE BLOCK STOP
    }

    $templ->param( 'Magnet_Start_Magnet' => $start_magnet );

    my %magnet_types = $self->{c__}->get_magnet_types( $self->{api_session__} );
    my $i = 0;
    my $count = -1;

    my @magnet_type_loop;
    foreach my $type (keys %magnet_types) {
        my %row_data;
        $row_data{Magnet_Type} = $type;
        $row_data{Magnet_Type_Name} = $magnet_types{$type};
        push ( @magnet_type_loop, \%row_data );
    }
    $templ->param( 'Magnet_Loop_Types' => \@magnet_type_loop );

    my @buckets = $self->{c__}->get_buckets( $self->{api_session__} );
    my @magnet_bucket_loop;
    foreach my $bucket (@buckets) {
        my %row_data;
        my $bcolor = $self->{c__}->get_bucket_color( $self->{api_session__}, $bucket );
        $row_data{Magnet_Bucket} = $bucket;
        $row_data{Magnet_Bucket_Color} = $bcolor;
        push ( @magnet_bucket_loop, \%row_data );
    }
    $templ->param( 'Magnet_Loop_Buckets' => \@magnet_bucket_loop );

    # magnet listing

    my @magnet_loop;
    for my $bucket ($self->{c__}->get_buckets_with_magnets( $self->{api_session__} )) {
        for my $type ($self->{c__}->get_magnet_types_in_bucket( $self->{api_session__}, $bucket )) {
            for my $magnet ($self->{c__}->get_magnets( $self->{api_session__}, $bucket, $type ))  {
                my %row_data;
                $count += 1;
                if ( ( $count < $start_magnet ) || ( $count > $stop_magnet ) ) {
                    next;
                }

                $i += 1;

                # to validate, must replace & with &amp; stan todo
                # note: come up with a smarter regex, this one's a
                # bludgeon another todo: Move this stuff into a
                # function to make text safe for inclusion in a form
                # field

                my $validatingMagnet = $magnet;
                $validatingMagnet =~ s/&/&amp;/g;
                $validatingMagnet =~ s/</&lt;/g;
                $validatingMagnet =~ s/>/&gt;/g;

                # escape quotation characters to avoid orphan data
                # within tags todo: function to make arbitrary data
                # safe for inclusion within a html tag attribute
                # (inside double-quotes)

                $validatingMagnet =~ s/\"/\&quot\;/g;

                $row_data{Magnet_Row_ID}     = $i;
                $row_data{Magnet_Bucket}     = $bucket;
                $row_data{Magnet_MType}      = $type;
                $row_data{Magnet_Validating} = $validatingMagnet;
                $row_data{Magnet_Size}       = max(length($magnet),50);

                my @type_loop;
                for my $mtype (keys %magnet_types) {
                    my %type_data;
                    my $selected = ( $mtype eq $type )?"selected":"";
                    $type_data{Magnet_Type_Name} = $mtype;
                    $type_data{Magnet_Type_Localized} = $self->{language__}{$magnet_types{$mtype}};
                    $type_data{Magnet_Type_Selected} = $selected;
                    push ( @type_loop, \%type_data );
                }
                $row_data{Magnet_Loop_Loop_Types} = \@type_loop;

                my @bucket_loop;
                my @buckets = $self->{c__}->get_buckets( $self->{api_session__} );
                foreach my $mbucket (@buckets) {
                    my %bucket_data;
                    my $selected = ( $bucket eq $mbucket )?"selected":"";
                    my $bcolor   = $self->{c__}->get_bucket_color( $self->{api_session__}, $mbucket );
                    $bucket_data{Magnet_Bucket_Bucket}   = $mbucket;
                    $bucket_data{Magnet_Bucket_Color}    = $bcolor;
                    $bucket_data{Magnet_Bucket_Selected} = $selected;
                    push ( @bucket_loop, \%bucket_data );

                }
                $row_data{Magnet_Loop_Loop_Buckets} = \@bucket_loop;
                push ( @magnet_loop, \%row_data );
            }
        }
    }

    $templ->param( 'Magnet_Loop_Magnets' => \@magnet_loop );
    $templ->param( 'Magnet_Count_Magnet' => $i );

    $self->http_ok( $client, $templ, 2 );
}

#----------------------------------------------------------------------------
#
# bucket_page - information about a specific bucket
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub bucket_page
{
    my ( $self, $client, $templ ) = @_;
    my $bucket = $self->{form_}{showbucket};

    $templ = $self->load_template__( 'bucket-page.thtml' );

    my $color = $self->{c__}->get_bucket_color( $self->{api_session__}, $bucket );
    $templ->param( 'Bucket_Main_Title' => sprintf( $self->{language__}{SingleBucket_Title}, "<font color=\"$color\">$bucket</font>" ) );

    my $bucket_count = $self->{c__}->get_bucket_word_count( $self->{api_session__}, $bucket );
    $templ->param( 'Bucket_Word_Count'   => $self->pretty_number( $bucket_count ) );
    $templ->param( 'Bucket_Unique_Count' => sprintf( $self->{language__}{SingleBucket_Unique}, $self->pretty_number( $self->{c__}->get_bucket_unique_count( $self->{api_session__}, $bucket ) ) ) );
    $templ->param( 'Bucket_Total_Word_Count' => $self->pretty_number( $self->{c__}->get_word_count( $self->{api_session__} ) || 0 ) );
    $templ->param( 'Bucket_Bucket' => $bucket );

    my $percent = '0%';
    if ( $self->{c__}->get_word_count( $self->{api_session__} ) > 0 )  {
        $percent = sprintf( '%6.2f%%', int( 10000 * $bucket_count / $self->{c__}->get_word_count( $self->{api_session__} ) ) / 100 );
    }
    $templ->param( 'Bucket_Percentage' => $percent );

    if ( $self->{c__}->get_bucket_word_count( $self->{api_session__}, $bucket ) > 0 ) {
        $templ->param( 'Bucket_If_Has_Words' => 1 );
        my @letter_data;
        for my $i ($self->{c__}->get_bucket_word_prefixes( $self->{api_session__}, $bucket )) {
            my %row_data;
            $row_data{Bucket_Letter} = $i;
            $row_data{Bucket_Bucket} = $bucket;
            $row_data{Session_Key}   = $self->{session_key__};
            if ( defined( $self->{form_}{showletter} ) && ( $i eq $self->{form_}{showletter} ) ) {
                $row_data{Bucket_If_Show_Letter} = 1;
                }
            push ( @letter_data, \%row_data );
                    }
        $templ->param( 'Bucket_Loop_Letters' => \@letter_data );

        if ( defined( $self->{form_}{showletter} ) ) {
            my $letter = $self->{form_}{showletter};

            $templ->param( 'Bucket_If_Show_Letter'   => 1 );
            $templ->param( 'Bucket_Word_Table_Title' =>               # PROFILE BLOCK START
                sprintf( $self->{language__}{SingleBucket_WordTable},
                         $bucket ) );                                 # PROFILE BLOCK STOP
            $templ->param( 'Bucket_Letter'           => $letter );

            my %word_count;

            for my $j ( $self->{c__}->get_bucket_word_list( $self->{api_session__}, $bucket, $letter ) ) {
                $word_count{$j} = $self->{c__}->get_count_for_word( $self->{api_session__}, $bucket, $j );
            }

            my @words = sort { $word_count{$b} <=> $word_count{$a} || $a cmp $b } keys %word_count;

            my @rows;
            while ( @words ) {
                my %row_data;
                my @cols;
                for ( 1 .. 6 ) {
                    my %cell_data;
                    my $word = shift @words;

                    $cell_data{'Bucket_Word'}       = $word;
                    $cell_data{'Bucket_Word_Count'} = $word_count{$word};
                    $cell_data{'Session_Key'}       = $self->{session_key__};

                    push @cols, \%cell_data;
                    last unless @words;
                }
                $row_data{'Bucket_Loop_Column'} = \@cols;
                push @rows, \%row_data;
            }
            $templ->param( 'Bucket_Loop_Row' => \@rows );
       }
    }

    $self->http_ok( $client, $templ, 1 );
}

#----------------------------------------------------------------------------
#
# bar_chart_100 - Output an HTML bar chart
#
# %values       A hash of bucket names with values in series 0, 1, 2, ...
#
#----------------------------------------------------------------------------
sub bar_chart_100
{
    my ( $self, %values ) = @_;

    my $templ = $self->load_template__( 'bar-chart-widget.thtml' );
    my $total_count = 0;
    my @xaxis = sort {
        if ( $self->{c__}->is_pseudo_bucket( $self->{api_session__}, $a ) == $self->{c__}->is_pseudo_bucket( $self->{api_session__}, $b ) ) {
            $a cmp $b;
        } else {
            $self->{c__}->is_pseudo_bucket( $self->{api_session__}, $a ) <=> $self->{c__}->is_pseudo_bucket( $self->{api_session__}, $b );
        }
    } keys %values;

    return '' if ( $#xaxis < 0 );

    my @series = sort keys %{$values{$xaxis[0]}};

    for my $bucket (@xaxis)  {
        $total_count += $values{$bucket}{0};
    }

    my @bucket_data;
    for my $bucket (@xaxis)  {
        my %bucket_row_data;

        $bucket_row_data{bar_bucket_color} = $self->{c__}->get_bucket_color( $self->{api_session__}, $bucket );
        $bucket_row_data{bar_bucket_name}  = $bucket;

        my @series_data;
        for my $s (@series) {
            my %series_row_data;
            my $value = $values{$bucket}{$s} || 0;
            my $count   = $self->pretty_number( $value );
            my $percent = '';

            if ( $s == 0 ) {
                my $d = $self->{language__}{Locale_Decimal};
                if ( $total_count == 0 ) {
                    $percent = " (  0$d" . "00%)";
                } else {
                   $percent = sprintf( " (%.2f%%)", int( $value * 10000 / $total_count ) / 100 );
                   $percent =~ s/\./$d/;
                }
            }

            if ( ( $s == 2 ) &&                                                            # PROFILE BLOCK START
                 ( $self->{c__}->is_pseudo_bucket( $self->{api_session__}, $bucket ) ) ) { # PROFILE BLOCK STOP
                $count = '';
                $percent = '';
            }

            $series_row_data{bar_count}   = $count;
            $series_row_data{bar_percent} = $percent;

            push @series_data, \%series_row_data;
        }
        $bucket_row_data{bar_loop_series} = \@series_data;
        push @bucket_data, \%bucket_row_data;
    }

    $templ->param( 'bar_loop_xaxis' => \@bucket_data );

    $templ->param( 'bar_colspan' => 3 + $#series );

    if ( $total_count != 0 ) {
        $templ->param( 'bar_if_total_count' => 1 );
        @bucket_data = ();

        foreach my $bucket (@xaxis) {
            my %bucket_row_data;
            my $percent = sprintf "%.2f", ( $values{$bucket}{0} * 10000 / $total_count ) / 100;
            if ( $percent != 0 )  {
                $bucket_row_data{bar_if_percent}   = 1;
                $bucket_row_data{bar_bucket_color} = $self->{c__}->get_bucket_color( $self->{api_session__}, $bucket );
                $bucket_row_data{bar_bucket_name2} = $bucket;
                $bucket_row_data{bar_width}        = $percent;
            }
            else {
                $bucket_row_data{bar_if_percent} = 0;
            }
            push @bucket_data, \%bucket_row_data;
        }
        $templ->param( 'bar_loop_total_xaxis' => \@bucket_data );
    }
    else {
        $templ->param( 'bar_if_total_count' => 0 );
    }

    return $templ->output();
}

#----------------------------------------------------------------------------
#
# corpus_page - the corpus management page
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub corpus_page
{
    my ( $self, $client, $templ ) = @_;

    my $session = $self->{api_session__};

    if ( defined( $self->{form_}{clearbucket} ) ) {
        $self->{c__}->clear_bucket( $session,                     # PROFILE BLOCK START
                                    $self->{form_}{showbucket} ); # PROFILE BLOCK STOP
    }

    if ( defined($self->{form_}{reset_stats}) ) {
        foreach my $bucket ($self->{c__}->get_all_buckets( $session )) {
            $self->set_bucket_parameter__( $bucket, 'count', 0 );
            $self->set_bucket_parameter__( $bucket, 'fpcount', 0 );
            $self->set_bucket_parameter__( $bucket, 'fncount', 0 );
        }
        my $lasttime = localtime;
        $self->config_( 'last_reset', $lasttime );
        $self->{configuration__}->save_configuration();
    }

    if ( defined($self->{form_}{showbucket}) )  {
        $self->bucket_page( $client, $templ );
        return;
    }

    # This regular expression defines the characters that are NOT valid
    # within a bucket name

    my $invalid_bucket_chars = '[^[:lower:]\-_0-9]';

    if ( ( defined($self->{form_}{cname}) ) && ( $self->{form_}{cname} ne '' ) ) {
        if ( $self->{form_}{cname} =~ /$invalid_bucket_chars/ )  {
            $templ->param( 'Corpus_If_Create_Error' => 1 );
        } else {
            if ( $self->{c__}->is_bucket( $session, $self->{form_}{cname} ) ||        # PROFILE BLOCK START
                $self->{c__}->is_pseudo_bucket( $session, $self->{form_}{cname} ) ) { # PROFILE BLOCK STOP
                $templ->param( 'Corpus_If_Create_Message' => 1 );
                $templ->param( 'Corpus_Create_Message' =>        # PROFILE BLOCK START
                    sprintf( $self->{language__}{Bucket_Error2},
                             $self->{form_}{cname} ) );          # PROFILE BLOCK STOP
            } else {
                $self->{c__}->create_bucket( $session, $self->{form_}{cname} );
                $templ->param( 'Corpus_If_Create_Message' => 1 );
                $templ->param( 'Corpus_Create_Message' =>        # PROFILE BLOCK START
                    sprintf( $self->{language__}{Bucket_Error3},
                             $self->{form_}{cname} ) );          # PROFILE BLOCK STOP
            }
       }
    }

    if ( ( defined($self->{form_}{delete}) ) && ( $self->{form_}{name} ne '' ) ) {
        $self->{form_}{name} = lc($self->{form_}{name});
        $self->{c__}->delete_bucket( $session, $self->{form_}{name} );
        $templ->param( 'Corpus_If_Delete_Message' => 1 );
        $templ->param( 'Corpus_Delete_Message' =>        # PROFILE BLOCK START
            sprintf( $self->{language__}{Bucket_Error6},
                     $self->{form_}{name} ) );           # PROFILE BLOCK STOP
    }

    if ( ( defined($self->{form_}{newname}) ) &&  # PROFILE BLOCK START
         ( $self->{form_}{oname} ne '' ) ) {      # PROFILE BLOCK STOP
        if ( ( $self->{form_}{newname} eq '' ) ||                       # PROFILE BLOCK START
             ( $self->{form_}{newname} =~ /$invalid_bucket_chars/ ) ) { # PROFILE BLOCK STOP
            $templ->param( 'Corpus_If_Rename_Error' => 1 );
        } else {
            $self->{form_}{oname} = lc($self->{form_}{oname});
            $self->{form_}{newname} = lc($self->{form_}{newname});
            if ( $self->{c__}->rename_bucket( $session, $self->{form_}{oname}, $self->{form_}{newname} ) == 1 ) {
                $templ->param( 'Corpus_If_Rename_Message' => 1 );
                $templ->param( 'Corpus_Rename_Message' =>        # PROFILE BLOCK START
                    sprintf( $self->{language__}{Bucket_Error5},
                             $self->{form_}{oname},
                             $self->{form_}{newname} ) );        # PROFILE BLOCK STOP
            } else {
                $templ->param( 'Corpus_If_Rename_Message' => 1 );
                $templ->param( 'Corpus_Rename_Message' => 'Internal error: rename failed' );
            }
        }
    }

    my @buckets = $self->{c__}->get_buckets( $session );

    my $total_count = 0;
    my @delete_data;
    my @rename_data;
    foreach my $bucket (@buckets) {
        my %delete_row;
        my %rename_row;
        $delete_row{Corpus_Delete_Bucket} = $bucket;
        $delete_row{Corpus_Delete_Bucket_Color} = $self->get_bucket_parameter__( $bucket, 'color' );
        $rename_row{Corpus_Rename_Bucket} = $bucket;
        $rename_row{Corpus_Rename_Bucket_Color} = $self->get_bucket_parameter__( $bucket, 'color' );
        $total_count += $self->get_bucket_parameter__( $bucket, 'count' );
        push ( @delete_data, \%delete_row );
        push ( @rename_data, \%rename_row );
    }
    $templ->param( 'Corpus_Loop_Delete_Buckets' => \@delete_data );
    $templ->param( 'Corpus_Loop_Rename_Buckets' => \@rename_data );

    my @pseudos = $self->{c__}->get_pseudo_buckets( $session );
    push @buckets, @pseudos;

    # Check whether the user requested any changes to the per-bucket settings

    if ( defined($self->{form_}{bucket_settings}) ) {
        my @parameters = qw/subject xtc xpl quarantine/;
        foreach my $bucket ( @buckets ) {
            foreach my $variable ( @parameters ) {
                my $bucket_param = $self->get_bucket_parameter__( $bucket, $variable );
                my $form_param = ( $self->{form_}{"${bucket}_$variable"} ) ? 1 : 0;

                if ( $form_param ne $bucket_param ) {
                    $self->set_bucket_parameter__( $bucket, $variable, $form_param );
                }
            }

            # Since color isn't coded binary and only used for
            # non-pseudo buckets, we have to handle it separately

            unless ( $self->{c__}->is_pseudo_bucket( $session, $bucket ) ) {
                my $bucket_color = $self->get_bucket_parameter__( $bucket, 'color' );
                my $form_color = $self->{form_}{"${bucket}_color"};

                if ( defined($form_color) && ( $form_color ne $bucket_color ) ) {
                    $self->set_bucket_parameter__( $bucket, 'color', $form_color );
                }
            }
        }
    }

    my @corpus_data;
    foreach my $bucket ( @buckets ) {
        my %row_data;
        $row_data{Corpus_Bucket}        = $bucket;
        $row_data{Corpus_Bucket_Color}  = $self->get_bucket_parameter__( $bucket, 'color' );
        $row_data{Corpus_Bucket_Unique} = $self->pretty_number(  $self->{c__}->get_bucket_unique_count( $session, $bucket ) );
        $row_data{Corpus_If_Bucket_Not_Pseudo} = !$self->{c__}->is_pseudo_bucket( $session, $bucket );
        $row_data{Corpus_If_Subject}    = $self->get_bucket_parameter__( $bucket, 'subject' );
        $row_data{Corpus_If_XTC}        = $self->get_bucket_parameter__( $bucket, 'xtc' );
        $row_data{Corpus_If_XPL}        = $self->get_bucket_parameter__( $bucket, 'xpl' );
        $row_data{Corpus_If_Quarantine} = $self->get_bucket_parameter__( $bucket, 'quarantine' );
        my @color_data;
        foreach my $color (@{$self->{c__}->{possible_colors__}} ) {
            my %color_row;
            $color_row{Corpus_Available_Color} = $color;
            $color_row{Corpus_Color_Selected}  = ( $row_data{Corpus_Bucket_Color} eq $color )?'selected':'';
            push ( @color_data, \%color_row );
        }
        $row_data{Session_Key}             = $self->{session_key__};
        $row_data{Corpus_Loop_Loop_Colors} = \@color_data;

        push ( @corpus_data, \%row_data );
    }
    $templ->param( 'Corpus_Loop_Buckets' => \@corpus_data );

    my %bar_values;
    for my $bucket (@buckets)  {
        $bar_values{$bucket}{0} = $self->get_bucket_parameter__( $bucket, 'count' );
        $bar_values{$bucket}{1} = $self->get_bucket_parameter__( $bucket, 'fpcount' );
        $bar_values{$bucket}{2} = $self->get_bucket_parameter__( $bucket, 'fncount' );
    }

    $templ->param( 'Corpus_Bar_Chart_Classification' => $self->bar_chart_100( %bar_values ) );

    @buckets = $self->{c__}->get_buckets( $session );

    delete $bar_values{unclassified};

    for my $bucket (@buckets)  {
        $bar_values{$bucket}{0} = $self->{c__}->get_bucket_word_count( $session, $bucket );
        delete $bar_values{$bucket}{1};
        delete $bar_values{$bucket}{2};
    }

    $templ->param( 'Corpus_Bar_Chart_Word_Counts' => $self->bar_chart_100( %bar_values ) );

    my $number = $self->pretty_number( $self->{c__}->get_unique_word_count( $session ) );
    $templ->param( 'Corpus_Total_Unique' => $number );

    my $pmcount = $self->pretty_number( $self->mcount__() );
    $templ->param( 'Corpus_Message_Count' => $pmcount );

    my $pecount = $self->pretty_number( $self->ecount__() );
    $templ->param( 'Corpus_Error_Count' => $pecount );

    my $accuracy = $self->{language__}{Bucket_NotEnoughData};
    my $percent = 0;
    if ( $self->mcount__() > $self->ecount__() ) {
        $percent = int( 10000 * ( $self->mcount__() - $self->ecount__() ) / $self->mcount__() ) / 100;
        $accuracy = "$percent%";
    }
    $templ->param( 'Corpus_Accuracy' => $accuracy );
    $templ->param( 'Corpus_If_Last_Reset' => 1 );
    $templ->param( 'Corpus_Last_Reset' => $self->config_( 'last_reset' ) );

    if ( ( defined($self->{form_}{lookup}) ) ||  # PROFILE BLOCK START
         ( defined($self->{form_}{word}) &&
           ( $self->{form_}{word} ne '' ) ) ) {  # PROFILE BLOCK STOP
        $templ->param( 'Corpus_If_Looked_Up' => 1 );
        $templ->param( 'Corpus_Word' => $self->{form_}{word} );
        my $word = $self->{form_}{word};

        if ( !( $word =~ /^[A-Za-z0-9\-_]+:/ ) ) {
            $word = $self->{c__}->{parser__}->{mangle__}->mangle( $word, 1 );
        }

        if ( !$word ) {
            $templ->param( 'Corpus_Lookup_Message' =>   # PROFILE BLOCK START
                           sprintf
                                $self->{language__}{Bucket_InIgnoredWords},
                                $self->{form_}{word} ); # PROFILE BLOCK STOP
        } else {
            my $max = 0;
            my $max_bucket = '';
            my $total = 0;
            foreach my $bucket (@buckets) {
                my $val = $self->{c__}->get_value_( $session, $bucket, $word );
                if ( $val != 0 ) {
                    my $prob = exp( $val );
                    $total += $prob;
                    if ( $prob > $max ) {
                        $max = $prob;
                        $max_bucket = $bucket;
                    }
                } else {

                    # Take into account the probability the Bayes
                    # calculation applies for the buckets in which the
                    # word is not found.

                    $total += exp( $self->{c__}->get_not_likely_( $session ) );
                }
            }

            my @lookup_data;
            foreach my $bucket (@buckets) {
                my $val = $self->{c__}->get_value_( $session, $bucket, $word );

                if ( $val != 0 ) {
                    my %row_data;
                    my $prob    = exp( $val );
                      my $n       = ($total > 0)?$prob / $total:0;
                    my $score   = ($#buckets >= 0)?($val - $self->{c__}->get_not_likely_( $session ) )/log(10.0):0;
                    my $d = $self->{language__}{Locale_Decimal};
                    my $normal  = sprintf("%.10f", $n);
                    $normal =~ s/\./$d/;
                    $score      = sprintf("%.10f", $score);
                    $score =~ s/\./$d/;
                    my $probf   = sprintf("%.10f", $prob);
                    $probf =~ s/\./$d/;
                    my $bold    = '';
                    my $endbold = '';
                    if ( $score =~ /^[^\-]/ ) {
                        $score = "&nbsp;$score";
                    }
                    $row_data{Corpus_If_Most_Likely} = ( $max == $prob );
                    $row_data{Corpus_Bucket}         = $bucket;
                    $row_data{Corpus_Bucket_Color}   = $self->get_bucket_parameter__( $bucket, 'color' );
                    $row_data{Corpus_Probability}    = $probf;
                    $row_data{Corpus_Normal}         = $normal;
                    $row_data{Corpus_Score}          = $score;
                    push ( @lookup_data, \%row_data );
                }
            }
            $templ->param( 'Corpus_Loop_Lookup' => \@lookup_data );

            if ( $max_bucket ne '' ) {
                $templ->param( 'Corpus_Lookup_Message' =>  # PROFILE BLOCK START
                               sprintf( $self->{language__}{Bucket_LookupMostLikely},
                                        $word,
                                        $self->{c__}->get_bucket_color( $session, $max_bucket ),
                                        $max_bucket ) );   # PROFILE BLOCK STOP
            } else {
                $templ->param( 'Corpus_Lookup_Message' =>  # PROFILE BLOCK START
                               sprintf( $self->{language__}{Bucket_DoesNotAppear},
                                        $word ) );         # PROFILE BLOCK STOP
            }
        }
    }

    $self->http_ok( $client, $templ, 1 );
}

#----------------------------------------------------------------------------
#
# compare_mf - Compares two mailfiles, used for sorting mail into order
#
#----------------------------------------------------------------------------
sub compare_mf
{
    $a =~ /popfile(\d+)=(\d+)\.msg/;
    my ( $ad, $am ) = ( $1, $2 );

    $b =~ /popfile(\d+)=(\d+)\.msg/;
    my ( $bd, $bm ) = ( $1, $2 );

    if ( $ad == $bd ) {
        return ( $bm <=> $am );
    } else {
        return ( $bd <=> $ad );
    }
}

#----------------------------------------------------------------------------
#
# set_history_navigator__
#
# Fix up the history-navigator-widget.thtml template
#
# $templ                - The template to fix up
# $start_message        - The number of the first message displayed
# $stop_message         - The number of the last message displayed
#
#----------------------------------------------------------------------------
sub set_history_navigator__
{
    my ( $self, $templ, $start_message, $stop_message ) = @_;

    $templ->param( 'History_Navigator_Fields' => $self->print_form_fields_(0,1,('session','filter','search','sort','negate' ) ) );

    my $page_size  = $self->config_( 'page_size' );
    my $query_size = $self->{history__}->get_query_size( $self->{q__} );

    if ( $start_message != 0 )  {
        $templ->param( 'History_Navigator_If_Previous' => 1 );
        $templ->param( 'History_Navigator_Previous'    => $start_message - $page_size );
    }

    # Only show two pages either side of the current page, the first
    # page and the last page
    #
    # e.g. [1] ... [4] [5] [6] [7] [8] ... [24]

    my $i = 0;
    my $p = 1;
    my $dots = 0;
    my @nav_data;
    while ( $i < $query_size ) {
        my %row_data;
        if ( ( $i == 0 ) ||                                        # PROFILE BLOCK START
             ( ( $i + $page_size ) >= $query_size ) ||
             ( ( ( $i - 2 * $page_size ) <= $start_message ) &&
               ( ( $i + 2 * $page_size ) >= $start_message ) ) ) { # PROFILE BLOCK STOP
            $row_data{History_Navigator_Page} = $p;
            $row_data{History_Navigator_I} = $i;
            if ( $i == $start_message ) {
                $row_data{History_Navigator_If_This_Page} = 1;
            } else {
                $row_data{History_Navigator_Fields} = $self->print_form_fields_(0,1,('session','filter','search','sort','negate'));
            }

            $dots = 1;
        } else {
            $row_data{History_Navigator_If_Spacer} = 1;
            if ( $dots ) {
                $row_data{History_Navigator_If_Dots} = 1;
            }
            $dots = 0;
        }

        $i += $page_size;
        $p++;
        push ( @nav_data, \%row_data );
    }
    $templ->param( 'History_Navigator_Loop' => \@nav_data );

    if ( $start_message < ( $query_size - $page_size ) )  {
        $templ->param( 'History_Navigator_If_Next' => 1 );
        $templ->param( 'History_Navigator_Next'    => $start_message + $page_size );
    }
}

#----------------------------------------------------------------------------
#
# set_magnet_navigator__
#
# Sets the magnet navigator up in a template
#
# $templ         - The loaded Magnet page template
# $start_magnet  - The number of the first magnet
# $stop_magnet   - The number of the last magnet
# $magnet_count  - Total number of magnets
#
#----------------------------------------------------------------------------
sub set_magnet_navigator__
{
    my ( $self, $templ, $start_magnet, $stop_magnet, $magnet_count ) = @_;

    my $page_size = $self->config_( 'page_size' );

    if ( $start_magnet != 0 )  {
        $templ->param( 'Magnet_Navigator_If_Previous' => 1 );
        $templ->param( 'Magnet_Navigator_Previous'    => $start_magnet - $page_size );
    }

    my $i = 0;
    my $count = 0;
    my @page_loop;
    while ( $i < $magnet_count ) {
        $templ->param( 'Magnet_Navigator_Enabled' => 1 );
        my %row_data;
        $count += 1;
        $row_data{Magnet_Navigator_Count} = $count;
        $row_data{Session_Key} = $self->{session_key__};
        if ( $i == $start_magnet )  {
            $row_data{Magnet_Navigator_If_This_Page} = 1;
        } else {
            $row_data{Magnet_Navigator_If_This_Page} = 0;
            $row_data{Magnet_Navigator_Start_Magnet} = $i;
        }

        $i += $page_size;
        push ( @page_loop, \%row_data );
    }
    $templ->param( 'Magnet_Navigator_Loop_Pages' => \@page_loop );

    if ( $start_magnet < ( $magnet_count - $page_size ) )  {
        $templ->param( 'Magnet_Navigator_If_Next' => 1 );
        $templ->param( 'Magnet_Navigator_Next'    => $start_magnet + $page_size );
    }
}


#----------------------------------------------------------------------------
#
# history_reclassify - handle the reclassification of messages on the
# history page
#
#----------------------------------------------------------------------------
sub history_reclassify
{
    my ( $self ) = @_;

    if ( defined( $self->{form_}{change} ) ) {

        # Look for all entries in the form of the form reclassify_X
        # and see if they have values, those that have values indicate
        # a reclassification

        # Set up %messages to map a slot ID to the new bucket

        my %messages;

        foreach my $key (keys %{$self->{form_}}) {
            if ( $key =~ /^reclassify_([0-9]+)$/ ) {
                if ( defined( $self->{form_}{$key} ) &&  # PROFILE BLOCK START
                     ( $self->{form_}{$key} ne '' ) ) {  # PROFILE BLOCK STOP
                    $messages{$1} = $self->{form_}{$key};
                }
            }
        }

        my %work;

        while ( my ( $slot, $newbucket ) = each %messages ) {
            push @{$work{$newbucket}},                      # PROFILE BLOCK START
                $self->{history__}->get_slot_file( $slot ); # PROFILE BLOCK STOP
            my @fields = $self->{history__}->get_slot_fields( $slot );
            my $bucket = $fields[8];
            $self->{c__}->reclassified(                           # PROFILE BLOCK START
                $self->{api_session__}, $bucket, $newbucket, 0 ); # PROFILE BLOCK STOP
            $self->{history__}->change_slot_classification(       # PROFILE BLOCK START
                 $slot, $newbucket, $self->{api_session__}, 0);   # PROFILE BLOCK STOP
            $self->{feedback}{$slot} = sprintf(                          # PROFILE BLOCK START
                 $self->{language__}{History_ChangedTo},
                 $self->{c__}->get_bucket_color(
                     $self->{api_session__}, $newbucket ), $newbucket ); # PROFILE BLOCK STOP
        }

        # At this point the work hash maps the buckets to lists of
        # files to reclassify, so run through them doing bulk updates

        foreach my $newbucket (keys %work) {
            $self->{c__}->add_messages_to_bucket(
                $self->{api_session__}, $newbucket, @{$work{$newbucket}} );
        }
    }
}

#----------------------------------------------------------------------------
#
# history_undo - handle undoing of reclassifications of messages on
# the history page
#
#----------------------------------------------------------------------------
sub history_undo
{
    my( $self ) = @_;

    # Look for all entries in the form of the form undo_X and see if
    # they have values, those that have values indicate a
    # reclassification

    foreach my $key (keys %{$self->{form_}}) {
        if ( $key =~ /^undo_([0-9]+)$/ ) {
            my $slot = $1;
            my @fields = $self->{history__}->get_slot_fields( $slot );
            my $bucket = $fields[8];
            my $newbucket = $self->{c__}->get_bucket_name(  # PROFILE BLOCK START
                                $self->{api_session__},
                                $fields[9] );               # PROFILE BLOCK STOP
            $self->{c__}->reclassified(                           # PROFILE BLOCK START
                $self->{api_session__}, $newbucket, $bucket, 1 ); # PROFILE BLOCK STOP
            $self->{history__}->change_slot_classification(       # PROFILE BLOCK START
                 $slot, $newbucket, $self->{api_session__}, 1 );  # PROFILE BLOCK STOP
            $self->{c__}->remove_message_from_bucket(             # PROFILE BLOCK START
                $self->{api_session__}, $bucket,
                $self->{history__}->get_slot_file( $slot ) );     # PROFILE BLOCK STOP
        }
    }
}

#----------------------------------------------------------------------------
#
# history_page - get the message classification history page
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub history_page
{
    my ( $self, $client, $templ ) = @_;

    # Set up default values for various form elements that have been
    # passed in or not so that we don't have to worry about undefined
    # values later on in the function

    $self->{form_}{sort}   = $self->{old_sort__} || '-inserted' if ( !defined( $self->{form_}{sort}   ) );
    $self->{form_}{search} = (!defined($self->{form_}{setsearch})?$self->{old_search__}:'') || '' if ( !defined( $self->{form_}{search} ) );
    $self->{form_}{filter} = (!defined($self->{form_}{setfilter})?$self->{old_filter__}:'') || '' if ( !defined( $self->{form_}{filter} ) );

    # If the user hits the Reset button on a search then we need to
    # clear the search value but make it look as though they hit the
    # search button so that sort_filter_history will get called below
    # to get the right values in history_keys

    if ( defined( $self->{form_}{reset_filter_search} ) ) {
        $self->{form_}{filter}    = '';
        $self->{form_}{negate}    = '';
        delete $self->{form_}{negate_array};
        $self->{form_}{search}    = '';
        $self->{form_}{setsearch} = 1;
    }

    # If the user is asking for a new sort option then it needs to get
    # stored in the sort form variable so that it can be used for
    # subsequent page views of the History to keep the sort in place

    $self->{form_}{sort} = $self->{form_}{setsort} if ( defined( $self->{form_}{setsort} ) );

    # Cache some values to keep interface widgets updated if history
    # is re-accessed without parameters

    $self->{old_sort__} = $self->{form_}{sort};

    # We are using a checkbox for negate, so we have to use an empty
    # hidden input of the same name and check for multiple occurences
    # or any of the name being defined

    if ( !defined( $self->{form_}{negate} ) ) {

        # if none of our negate inputs are active,
        # this is a "clean" access of the history

        $self->{form_}{negate} = $self->{old_negate__} || '';

    } elsif ( defined( $self->{form_}{negate_array} ) ) {
        for ( @{$self->{form_}{negate_array}} ) {
            if ($_ ne '') {
                $self->{form_}{negate} = 'on';
                $self->{old_negate__} = 'on';
                last;
            }
        }
    } else {

        # We have a negate form, but no array.. this is likely the
        # hidden input, so this is not a "clean" visit

        $self->{old_negate__} = $self->{form_}{negate};
    }

    # Information from submit buttons isn't always preserved if the
    # buttons aren't pressed. This compares values in some fields and
    # sets the button-values as though they had been pressed

    # Set setsearch if search changed and setsearch is undefined

    $self->{form_}{setsearch} = 'on' if ( ( ( !defined($self->{old_search__}) && ($self->{form_}{search} ne '') ) || ( defined($self->{old_search__}) && ( $self->{old_search__} ne $self->{form_}{search} ) ) ) && !defined($self->{form_}{setsearch} ) );
    $self->{old_search__} = $self->{form_}{search};

    # Set setfilter if filter changed and setfilter is undefined

    $self->{form_}{setfilter} = 'Filter' if ( ( ( !defined($self->{old_filter__}) && ($self->{form_}{filter} ne '') ) || ( defined($self->{old_filter__}) && ( $self->{old_filter__} ne $self->{form_}{filter} ) ) ) && !defined($self->{form_}{setfilter} ) );
    $self->{old_filter__} = $self->{form_}{filter};

    # Set up the text that will appear at the top of the history page
    # indicating the current filter and search settings

    my $filter = $self->{form_}{filter};

    # Handle the reinsertion of a message file or the user hitting the
    # undo button

    $self->history_reclassify();
    $self->history_undo();

    # Handle removal of one or more items from the history page.  Two
    # important possibilities:
    #
    # clearpage is defined: this will delete everything on the page
    # which means we will call delete_slot in the history with the ID
    # of ever message displayed.  The IDs are encoded in the hidden
    # rowid_* form elements.
    #
    # clearchecked is defined: this will delete the messages that are
    # checked (i.e. the check box has been clicked).  The check box is
    # called remove_* in the form_ hash once we get here.
    #
    # The third possibility is clearall which is handled below and
    # uses the delete_query API of History.

    if ( defined( $self->{form_}{clearpage} ) ) {

        # Remove the list of messages on the current page

        $self->{history__}->start_deleting();
        for my $i ( keys %{$self->{form_}} ) {
            if ( $i =~ /^rowid_(\d+)$/ ) {
                $self->log_( 1, "clearpage $i" );
                $self->{history__}->delete_slot( $1, 1 );
            }
        }
        $self->{history__}->stop_deleting();
    }

    if ( defined( $self->{form_}{clearchecked} ) ) {

        # Remove the list of marked messages using the array of
        # "remove" checkboxes

        $self->{history__}->start_deleting();
        for my $i ( keys %{$self->{form_}} ) {
            if ( $i =~ /^remove_(\d+)$/ ) {
                my $slot = $1;
                if ( $self->{form_}{$i} ne '' ) {
                    $self->log_( 1, "clearchecked $i" );
                    $self->{history__}->delete_slot( $slot );
                }
            }
        }
        $self->{history__}->stop_deleting();
    }

    # Handle clearing the history files, there are two options here,
    # clear the current page or clear all the files in the cache

    if ( defined( $self->{form_}{clearall} ) ) {
        $self->{history__}->delete_query( $self->{q__} );
    }

    $self->{history__}->set_query( $self->{q__},                       # PROFILE BLOCK START
                                   $self->{form_}{filter},
                                   $self->{form_}{search},
                                   $self->{form_}{sort},
                                   ( $self->{form_}{negate} ne '' ) ); # PROFILE BLOCK STOP

    # Redirect somewhere safe if non-idempotent action has been taken

    if ( defined( $self->{form_}{clearpage}      ) ||  # PROFILE BLOCK START
         defined( $self->{form_}{undo}           ) ||
         defined( $self->{form_}{reclassify}     ) ) { # PROFILE BLOCK STOP
        return $self->http_redirect_( $client, "/history?" . $self->print_form_fields_(1,0,('start_message','filter','search','sort','session','negate') ) );
    }

    my $session    = $self->{api_session__};
    my $page_size  = $self->config_( 'page_size' );
    my $query_size = $self->{history__}->get_query_size( $self->{q__} );

    $templ->param( 'History_Field_Search'  => $self->{form_}{search} );
    $templ->param( 'History_Field_Not'     => $self->{form_}{negate} );
    $templ->param( 'History_If_Search'     => defined( $self->{form_}{search} ) );
    $templ->param( 'History_Field_Sort'    => $self->{form_}{sort} );
    $templ->param( 'History_Field_Filter'  => $self->{form_}{filter} );
    $templ->param( 'History_If_MultiPage'  => $page_size <= $query_size );
    $templ->param( 'History_Search_Filter_Highlight'  => $self->config_( 'search_filter_highlight' ) );

    my @buckets = $self->{c__}->get_buckets( $session );

    my @bucket_data;
    foreach my $bucket (@buckets) {
        my %row_data;
        $row_data{History_Bucket} = $bucket;
        $row_data{History_Bucket_Color} =                  # PROFILE BLOCK START
            $self->{c__}->get_bucket_parameter( $session,
                                                $bucket,
                                                'color' ); # PROFILE BLOCK STOP
        push ( @bucket_data, \%row_data );
    }

    my @sf_bucket_data;
    foreach my $bucket (@buckets) {
        my %row_data;
        $row_data{History_Bucket} = $bucket;
        $row_data{History_Selected} = ( defined( $self->{form_}{filter} ) && ( $self->{form_}{filter} eq $bucket ) )?'selected':'';
        $row_data{History_Bucket_Color}  =                 # PROFILE BLOCK START
            $self->{c__}->get_bucket_parameter( $session,
                                                $bucket,
                                                'color' ); # PROFILE BLOCK STOP
        push ( @sf_bucket_data, \%row_data );
    }
    $templ->param( 'History_Loop_SF_Buckets' => \@sf_bucket_data );

    $templ->param( 'History_Filter_Magnet' => ($self->{form_}{filter} eq '__filter__magnet')?'selected':'' );
    $templ->param( 'History_Filter_Unclassified' => ($self->{form_}{filter} eq 'unclassified')?'selected':'' );
    $templ->param( 'History_Filter_Reclassified' => ($self->{form_}{filter} eq '__filter__reclassified')?'selected':'' );
    $templ->param( 'History_Field_Not' => ($self->{form_}{negate} ne '')?'checked':'' );

    if ( $query_size > 0 ) {
        $templ->param( 'History_If_Some_Messages' => 1 );
        $templ->param( 'History_Count' => $self->pretty_number( $query_size ) );

        my $start_message = 0;
        $start_message = $self->{form_}{start_message} if ( ( defined($self->{form_}{start_message}) ) && ($self->{form_}{start_message} > 0 ) );
        if ( $start_message >= $query_size ) {
            $start_message -= $page_size;
        }
        if ( $start_message < 0 ) {
            $start_message = 0;
        }
        $self->{form_}{start_message} = $start_message;
        $templ->param( 'History_Start_Message' => $start_message );

        my $stop_message  = $start_message + $page_size - 1;
        $stop_message = $query_size - 1 if ( $stop_message >= $query_size );

        $self->set_history_navigator__( $templ, $start_message, $stop_message );

        # Work out which columns to show by splitting the columns
        # parameter at commas keeping all the items that start with a
        # +, and then strip the +

        my @columns = split( ',', $self->config_( 'columns' ) );
        my @header_data;
        my $colspan = 1;
        my $length = 90;

        foreach my $header (@columns) {
            my %row_data;
            $header =~ /^(.)/;
            next if ( $1 eq '-' );
            $header =~ s/^.//;
            $colspan++;
            $row_data{History_Fields} =                      # PROFILE BLOCK START
                $self->print_form_fields_(1,1,
                    ('filter','session','search','negate')); # PROFILE BLOCK STOP
            $row_data{History_Sort}   =                      # PROFILE BLOCK START
                ( $self->{form_}{sort} eq $header )?'-':'';  # PROFILE BLOCK STOP
            $row_data{History_Header} = $header;

            my $label = '';
            if ( defined $self->{language__}{ $headers_table{$header} }) {
                $label = $self->{language__}{ $headers_table{$header} };
            } else {
                $label = $headers_table{$header};
            }
            $row_data{History_Label} = $label;
            $row_data{History_If_Sorted} =                      # PROFILE BLOCK START
                ( $self->{form_}{sort} =~ /^\-?\Q$header\E$/ ); # PROFILE BLOCK STOP
            $row_data{History_If_Sorted_Ascending} =            # PROFILE BLOCK START
                ( $self->{form_}{sort} !~ /^-/ );               # PROFILE BLOCK STOP
            push ( @header_data, \%row_data );
            $length -= 10;
        }
        $templ->param( 'History_Loop_Headers' => \@header_data );
        $templ->param( 'History_Colspan' => $colspan );

        my @rows = $self->{history__}->get_query_rows( # PROFILE BLOCK START
            $self->{q__}, $start_message+1,
            $stop_message - $start_message + 1 );      # PROFILE BLOCK STOP

        my @history_data;
        my $i = $start_message;
        @columns = split( ',', $self->config_( 'columns' ) );
        my $last = -1;
        if ( defined($self->{form_}{automatic}) ) {
            $self->config_( 'column_characters', 0 );
        }
        if ( $self->config_( 'column_characters' ) != 0 ) {
            $length = $self->config_( 'column_characters' );
        }
        if ( defined($self->{form_}{increase}) ) {
            $length++;
            $self->config_( 'column_characters', $length );
        }
        if ( defined($self->{form_}{decrease}) ) {
            $length--;
            if ( $length < 5 ) {
                $length = 5;
            }
            $self->config_( 'column_characters', $length );
        }
        foreach my $row (@rows) {
            my %row_data;
            my $mail_file = $row_data{History_Mail_File} = $$row[0];
            foreach my $header (@columns) {
                $header =~ /(.)(.+)/;
                $row_data{"History_If_$2"} = ( $1 eq '+')?1:0;
            }

            if ( $self->config_( 'language' ) eq 'Nihongo' ) {
                # Remove wrong characters as euc-jp.
                for my $i (1..4) {
                    my $result = '';
                    while ( $$row[$i] =~ /((?:$euc_jp){1,300})/og ) {
                        $result .= $1;
                    }
                    $$row[$i] = $result;
                }
            }

            $row_data{History_Arrived}       = $self->pretty_date__( $$row[7] );
            $row_data{History_From}          = $$row[1];
            $row_data{History_To}            = $$row[2];
            $row_data{History_Cc}            = $$row[3];
            $row_data{History_Date}          = $self->pretty_date__( $$row[5] );
            $row_data{History_Subject}       = $$row[4];
            $row_data{History_Short_From}    = $self->shorten__( $$row[1], $length );
            $row_data{History_Short_To}      = $self->shorten__( $$row[2], $length );
            $row_data{History_Short_Cc}      = $self->shorten__( $$row[3], $length );
            $row_data{History_Short_Subject} = $self->shorten__( $$row[4], $length );
            my $bucket = $row_data{History_Bucket} = $$row[8];
            $row_data{History_Bucket_Color}  = $self->{c__}->get_bucket_parameter( $self->{api_session__},  # PROFILE BLOCK START
                                                                          $bucket,
                                                                          'color' );                        # PROFILE BLOCK STOP
            $row_data{History_If_Reclassified} = ( $$row[9] != 0 );
            $row_data{History_I}             = $$row[0];
            $row_data{History_I1}            = $$row[0];
            $row_data{History_Fields}        = $self->print_form_fields_(0,1,('start_message','session','filter','search','sort','negate' ) );
            $row_data{History_If_Not_Pseudo} = !$self->{c__}->is_pseudo_bucket( $self->{api_session__},  # PROFILE BLOCK START
                                                                           $bucket );                    # PROFILE BLOCK STOP
            $row_data{History_If_Magnetized} = ($$row[11] ne '');
            $row_data{History_MagnetUsed}    = $self->{language__}{History_MagnetUsed} if $$row[11] ne '';
            $row_data{History_Magnet}        = $$row[11];
            my $size = $$row[12];
            if ( defined $size ) {
                if ( $size >= 1024 * 1024 ) {
                    $row_data{History_Size} = sprintf $self->{language__}{History_Size_MegaBytes}, $size / ( 1024 * 1024 );
                }
                elsif ( $size >= 1024 ) {
                    $row_data{History_Size} = sprintf $self->{language__}{History_Size_KiloBytes}, $size / 1024;
                }
                else {
                    $row_data{History_Size} = sprintf $self->{language__}{History_Size_Bytes}, $size;
                }
            }
            else {
                $row_data{History_Size} = "?";
            }
            $row_data{History_Loop_Loop_Buckets} = \@bucket_data;
            if ( defined $self->{feedback}{$mail_file} ) {
                $row_data{History_If_Feedback} = 1;
                $row_data{History_Feedback} = $self->{feedback}{$mail_file};
                delete $self->{feedback}{$mail_file};
            }
            $row_data{Session_Key} = $self->{session_key__};

            if ( ( $last != -1 ) &&                           # PROFILE BLOCK START
                 ( $self->{form_}{sort} =~ /inserted/ ) &&
                 ( $self->config_( 'session_dividers' ) ) ) { # PROFILE BLOCK STOP
                $row_data{History_If_Session} =        # PROFILE BLOCK START
                    ( abs( $$row[7] - $last ) > 300 ); # PROFILE BLOCK STOP
            }
            # we set this here so feedback lines will also
            # get the correct colspan:
            $row_data{History_Colspan} = $colspan+1;

            $last = $$row[7];

            $row_data{Localize_History_Reclassified} =     # PROFILE BLOCK START
                $self->{language__}{History_Reclassified}; # PROFILE BLOCK STOP
            $row_data{Localize_Undo} = $self->{language__}{Undo};
            push ( @history_data, \%row_data );
        }
        $templ->param( 'History_Loop_Messages' => \@history_data );
    }

    $self->http_ok( $client, $templ, 0 );
}

sub shorten__
{
    my ( $self, $string, $length ) = @_;

    if ( length($string) > $length ) {
        $string =~ /(.{$length})/;
        $1 =~ /((?:$euc_jp)*)/o if ( $self->config_( 'language' ) eq 'Nihongo' );
        $string = "$1...";
    }

    return $string;
}

#----------------------------------------------------------------------------
#
# view_page - Shows a single email
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub view_page
{
    my ( $self, $client, $templ ) = @_;

    if ( !$self->{history__}->is_valid_slot( $self->{form_}{view} ) ) {
        return $self->http_redirect_( $client,
             "/history?session=$self->{session_key__}" );
    }

    my $mail_file = $self->{history__}->get_slot_file( $self->{form_}{view} );
    my $start_message = $self->{form_}{start_message} || 0;

    my ( $id, $from, $to, $cc, $subject, $date, $hash, $inserted,    # PROFILE BLOCK START
        $bucket, $reclassified, $bucketid, $magnet ) =
        $self->{history__}->get_slot_fields( $self->{form_}{view} ); # PROFILE BLOCK STOP

    my $session   = $self->{api_session__};
    my $color = $self->{c__}->get_bucket_color(  # PROFILE BLOCK START
                    $session, $bucket );         # PROFILE BLOCK STOP
    my $page_size = $self->config_( 'page_size' );

    $self->{form_}{sort}   = '' if ( !defined( $self->{form_}{sort}   ) );
    $self->{form_}{search} = '' if ( !defined( $self->{form_}{search} ) );
    $self->{form_}{filter} = '' if ( !defined( $self->{form_}{filter} ) );
    if ( !defined( $self->{form_}{format} ) ) {
        $self->{form_}{format} = $self->config_( 'wordtable_format' );
    }

    # Provide message in plain text for user download/recovery purposes.

    if ( defined( $self->{form_}{text} ) ) {
        $self->http_file_( $client, $self->{history__}->get_slot_file( $self->{form_}{view} ), 'application/save-as' );
        return 1;
    }

    # If a format change was requested for the word matrix, record it
    # in the configuration and in the classifier options.

    $self->{c__}->wmformat( $self->{form_}{format} );

    my $index = $self->{form_}{view};

    $templ->param( 'View_All_Fields'       => $self->print_form_fields_(1,1,('start_message','filter','session','search','sort','negate')));
    $templ->param( 'View_Field_Search'     => $self->{form_}{search} );
    $templ->param( 'View_Field_Negate'     => $self->{form_}{negate} );
    $templ->param( 'View_Field_Sort'       => $self->{form_}{sort}   );
    $templ->param( 'View_Field_Filter'     => $self->{form_}{filter} );

    $templ->param( 'View_From'             => $from );
    $templ->param( 'View_To'               => $to );
    $templ->param( 'View_Cc'               => $cc );
    $templ->param( 'View_Date'             => $self->pretty_date__( $date, 1 ) );
    $templ->param( 'View_Subject'          => $subject );
    $templ->param( 'View_Bucket'           => $bucket );
    $templ->param( 'View_Bucket_Color'     => $color );

    $templ->param( 'View_Index'            => $index );
    $templ->param( 'View_This'             => $index );
    $templ->param( 'View_This_Page'        => (( $index ) >= $start_message )?$start_message:($start_message - $page_size)); # TODO

    $templ->param( 'View_If_Reclassified'  => $reclassified );
    if ( $reclassified ) {
        $templ->param( 'View_Already' => sprintf( $self->{language__}{History_Already}, ($color || ''), ($bucket || '') ) );
    } else {
        $templ->param( 'View_If_Magnetized' => ( $magnet ne '' ) );
        if ( $magnet eq '' ) {
            my @bucket_data;
            foreach my $abucket ($self->{c__}->get_buckets( $session )) {
                my %row_data;
                $row_data{View_Bucket_Color} = $self->{c__}->get_bucket_color( $session, $abucket );
                $row_data{View_Bucket} = $abucket;
                push ( @bucket_data, \%row_data );
            }
            $templ->param( 'View_Loop_Buckets' => \@bucket_data );
        } else {
            $templ->param( 'View_Magnet' => $magnet );
        }
    }

    if ( $magnet eq '' ) {
        my %matrix;
        my %idmap;

        # Enable saving of word-scores

        $self->{c__}->wordscores( 1 );

        # Build the scores by classifying the message, since
        # get_html_colored_message has parsed the message for us we do
        # not need to parse it again and hence we pass in undef for
        # the filename

        my $current_class = 'unclassified';

        if ( -f $mail_file ) {
            $current_class = $self->{c__}->classify(               # PROFILE BLOCK START
                $session, $mail_file, $templ, \%matrix, \%idmap ); # PROFILE BLOCK STOP
        } else {
            $self->log_( 0, "Message file '$mail_file' is not found." );
        }

        # Check whether the original classfication is still valid.  If
        # not, add a note at the top of the page:

        if ( $current_class ne $bucket ) {
            my $new_color = $self->{c__}->get_bucket_color(  # PROFILE BLOCK START
                $session, $current_class );                  # PROFILE BLOCK STOP
            $templ->param( 'View_If_Class_Changed' => 1 );
            $templ->param( 'View_Class_Changed' => $current_class );
            $templ->param( 'View_Class_Changed_Color' => $new_color );
        }

        # Disable, print, and clear saved word-scores

        $self->{c__}->wordscores( 0 );

        if ( -f $mail_file ) {
            $templ->param( 'View_Message' =>                     # PROFILE BLOCK START
                $self->{c__}->fast_get_html_colored_message(
                    $session, $mail_file, \%matrix, \%idmap ) ); # PROFILE BLOCK STOP
        }

        # We want to insert a link to change the output format at the
        # start of the word matrix.  The classifier puts a comment in
        # the right place, which we can replace by the link.  (There's
        # probably a better way.)

        my $view = $self->{language__}{View_WordProbabilities};
        if ( $self->{form_}{format} eq 'freq' ) {
            $view = $self->{language__}{View_WordFrequencies};
        }
        if ( $self->{form_}{format} eq 'score' ) {
            $view = $self->{language__}{View_WordScores};
        }

        if ( $self->{form_}{format} ne '' ) {
            $templ->param( 'View_If_Format' => 1 );
            $templ->param( 'View_View' => $view );
        }
        if ($self->{form_}{format} ne 'freq' ) {
            $templ->param( 'View_If_Format_Freq' => 1 );
        }
        if ($self->{form_}{format} ne 'prob' ) {
            $templ->param( 'View_If_Format_Prob' => 1 );
        }
        if ($self->{form_}{format} ne 'score' ) {
            $templ->param( 'View_If_Format_Score' => 1 );
        }
    } else {

        # TODO: See comment below for details

        # $magnet =~ /(.+): ([^\r\n]+)/;
        # my $header = $1;
        # my $text   = $2;

        my $body = '<tt>';

        open MESSAGE, '<' . $mail_file;
        my $line;

        while ($line = <MESSAGE>) {
            $line =~ s/</&lt;/g;
            $line =~ s/>/&gt;/g;

            $line =~ s/([^\r\n]{100,150} )/$1<br \/>/g;
            $line =~ s/([^ \r\n]{150})/$1<br \/>/g;
            $line =~ s/[\r\n]+/<br \/>/g;

            # TODO: This code is now useless because the magnet itself
            # doesn't contain the information about which header we are
            # looking for.  Ultimately, we need to fix this but I decided
            # for v0.22.0 release to not make further changes and leave this
            # code as unfixed.

            # if ( $line =~ /^([A-Za-z-]+): ?([^\n\r]*)/ ) {
            #    my $head = $1;
            #    my $arg  = $2;

            #    if ( $head =~ /\Q$header\E/i ) {

            #        $text =~ s/</&lt;/g;
            #        $text =~ s/>/&gt;/g;

            #        if ( $arg =~ /\Q$text\E/i ) {
            #            my $new_color = $self->{c__}->get_bucket_color( $self->{api_session__}, $bucket );
            #            $line =~ s/(\Q$text\E)/<b><font color=\"$new_color\">$1<\/font><\/b>/;
            #        }
            #    }
            # }

            $body .= $line;
        }
        close MESSAGE;
        $body .= '</tt>';
        $templ->param( 'View_Message' => $body );
    }

    if ( $magnet ne '' ) {
        $templ->param( 'View_Magnet_Reason' => sprintf( $self->{language__}{History_MagnetBecause},  # PROFILE BLOCK START
                          $color, $bucket,
                          Classifier::MailParse->splitline( $magnet, 0 )
            ) );                                                                                     # PROFILE BLOCK STOP
    }

    $self->http_ok( $client, $templ, 0 );
}

#----------------------------------------------------------------------------
#
# password_page - Simple page asking for the POPFile password
#
# $client     The web browser to send the results to
# $error      1 if the user previously typed the password incorrectly
# $redirect   The page to go to on a correct password
#
#----------------------------------------------------------------------------
sub password_page
{
    my ( $self, $client, $error, $redirect ) = @_;
    my $session_temp = $self->{session_key__};

    # Show a page asking for the password with no session key
    # information on it

    $self->{session_key__} = '';
    my $templ = $self->load_template__( 'password-page.thtml' );
    $self->{session_key__} = $session_temp;

    # These things need fixing up on the password page:
    #
    # The page to redirect to if the user gets the password right
    # An error if they typed in the wrong password

    $templ->param( 'Password_If_Error' => $error );
    $templ->param( 'Password_Redirect' => $redirect );

    $self->http_ok( $client, $templ );
}

#----------------------------------------------------------------------------
#
# session_page - Simple page information the user of a bad session key
#
# $client     The web browser to send the results to
#
#----------------------------------------------------------------------------
sub session_page
{
    my ( $self, $client ) = @_;

    my $templ = $self->load_template__( 'session-page.thtml' );
    $self->http_ok( $client, $templ );
}

#----------------------------------------------------------------------------
#
# load_template__
#
# Loads the named template and returns a new HTML::Template object
#
# $template          The name of the template to load from the current skin
#
#----------------------------------------------------------------------------
sub load_template__
{
    my ( $self, $template ) = @_;

    # First see if that template exists in the currently selected
    # skin, if it does not then load the template from the default.
    # This allows a skin author to change just a single part of
    # POPFile with duplicating that entire set of templates

    my $root = 'skins/' . $self->config_( 'skin' ) . '/';
    my $template_root = $root;
    my $file = $self->get_root_path_( "$template_root$template" );
    if ( !( -e $file ) ) {
        $template_root = 'skins/default/';
        $file = $self->get_root_path_( "$template_root$template" );
    }

    my $css = $self->get_root_path_( $root . 'style.css' );
    if ( !( -e $css ) ) {
        $root = 'skins/default/';
    }

    my $templ = HTML::Template->new(  # PROFILE BLOCK START
        filename          => $file,
        case_sensitive    => 1,
        loop_context_vars => 1,
        cache             => $self->config_( 'cache_templates' ),
        die_on_bad_params => $self->config_( 'strict_templates' ),
        search_path_on_include => 1,
        path => [$self->get_root_path_( "$root" ),
                 $self->get_root_path_( 'skins/default' ) ]
                                   ); # PROFILE BLOCK STOP

    # Set a variety of common elements that are used repeatedly
    # throughout POPFile's pages

    my $now = time;
    my %fixups = ( 'Skin_Root'               => $root,  # PROFILE BLOCK START
                   'Session_Key'             => $self->{session_key__},
                   'Common_Bottom_Date'      => $self->pretty_date__( $now ),
                   'Common_Bottom_LastLogin' => $self->{last_login__},
                   'Common_Bottom_Version'   => $self->version(),
                   'If_Show_Bucket_Help'     => $self->config_( 'show_bucket_help' ),
                   'If_Show_Training_Help'   => $self->config_( 'show_training_help' )
                 );                                     # PROFILE BLOCK STOP

    foreach my $fixup (keys %fixups) {
        if ( $templ->query( name => $fixup ) ) {
            $templ->param( $fixup => $fixups{$fixup} );
        }
    }

    $self->localize_template__( $templ );

    return $templ;
}

#----------------------------------------------------------------------------
#
# localize_template__
#
# Localize a template by converting all the Localize_X variables to the
# appropriate variable X from the language__ hash.
#
#----------------------------------------------------------------------------
sub localize_template__
{
    my ( $self, $templ ) = @_;

    # Localize the template in use.
    #
    # Templates are automatically localized.  Any TMPL_VAR that begins
    # with Localize_ will be fixed up automatically with the
    # appropriate string for the language in use.  For example if you
    # write
    #
    #     <TMPL_VAR name="Localize_Foo_Bar">
    #
    # this will automatically be converted to the string associated
    # with Foo_Bar in the current language file.

    my @vars = $templ->param();

    foreach my $var (@vars) {
        if ( $var =~ /^Localize_(.*)/ ) {
            $templ->param( $var => $self->{language__}{$1} );
        }
    }
}

#----------------------------------------------------------------------------
#
# load_skins__
#
# Gets the names of all the directory in the skins subdirectory and
# loads them into the skins array.
#
#----------------------------------------------------------------------------
sub load_skins__
{
    my ( $self ) = @_;

    @{$self->{skins__}} = glob $self->get_root_path_( 'skins/*' );

    for my $i (0..$#{$self->{skins__}}) {
        $self->{skins__}[$i] =~ s/\/$//;
        $self->{skins__}[$i] .= '/';
    }
}

#----------------------------------------------------------------------------
#
# load_languages__
#
# Get the names of the available languages for the user interface
#
#----------------------------------------------------------------------------
sub load_languages__
{
    my ( $self ) = @_;

    @{$self->{languages__}} = glob $self->get_root_path_( 'languages/*.msg' );

    for my $i (0..$#{$self->{languages__}}) {
        $self->{languages__}[$i] =~ s/.*\/(.+)\.msg$/$1/;
    }
}

#----------------------------------------------------------------------------
#
# change_session_key__
#
# Changes the session key, the session key is a randomly chosen 6 to
# 10 character key that protects and identifies sessions with the
# POPFile user interface.  At the current time it is primarily used
# for two purposes: to prevent a malicious user telling the browser to
# hit a specific URL causing POPFile to do something undesirable (like
# shutdown) and to handle the password mechanism: if the session key
# is wrong the password challenge is made.
#
# The characters valid in the session key are A-Z, a-z and 0-9
#
#----------------------------------------------------------------------------
sub change_session_key__
{
    my ( $self ) = @_;

    my @chars = ( 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',   # PROFILE BLOCK START
                  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'U', 'V', 'W', 'X', 'Y',
                  'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A' ); # PROFILE BLOCK STOP

    $self->{session_key__} = '';

    my $length = int( 6 + rand(4) );

    for my $i (0 .. $length) {
        my $random = $chars[int( rand(36) )];

        # Just to add spice to things we sometimes lowercase the value

        if ( rand(1) < rand(1) ) {
            $random = lc($random);
        }

        $self->{session_key__} .= $random;
    }
}

#----------------------------------------------------------------------------
#
# load_language
#
# Fill the language hash with the language strings that are from the
# named language file
#
# $lang    - The language to load (no .msg extension)
#
#----------------------------------------------------------------------------
sub load_language
{
    my ( $self, $lang ) = @_;

    if ( open LANG, '<' . $self->get_root_path_( "languages/$lang.msg" ) ) {
        while ( <LANG> ) {
            next if ( /[ \t]*#/ );

            if ( /([^\t ]+)[ \t]+(.+)/ ) {
                my ( $id, $value )  = ( $1, $2 );
                if ( $value =~ /^\"(.+)\"$/ ) {
                    $value = $1;
                }
                my $msg = ($self->config_( 'test_language' )) ? $id : $value;
                $msg =~ s/[\r\n]//g;

                $self->{language__}{$id} = $msg;
            }
        }
        close LANG;
    }
}

#----------------------------------------------------------------------------
#
# calculate_today - set the global $self->{today__} variable to the
# current day in seconds
#
#----------------------------------------------------------------------------
sub calculate_today
{
    my ( $self ) = @_;

    $self->{today__} = int( time / $seconds_per_day ) * $seconds_per_day; # A slash / for eclipse
}

#----------------------------------------------------------------------------
#
# print_form_fields_ - Returns a form string containing any presently
# defined form fields
#
# $first - 1 if the form field is at the beginning of a query, 0
#     otherwise
# $in_href - 1 if the form field is printing in a href, 0
#     otherwise (eg, for a 302 redirect)
# $include - a list of fields to
#     return
#
#----------------------------------------------------------------------------
sub print_form_fields_
{
    my ($self, $first, $in_href, @include) = @_;

    my $amp;
    if ($in_href) {
        $amp = '&amp;';
    } else {
        $amp = '&';
    }

    my $count = 0;
    my $formstring = '';

    $formstring = "$amp" if (!$first);

    foreach my $field ( @include ) {
        if ($field eq 'session') {
            $formstring .= "$amp" if ($count > 0);
            $formstring .= "session=$self->{session_key__}";
            $count++;
            next;
            }
        unless ( !defined($self->{form_}{$field}) || ( $self->{form_}{$field} eq '' ) ) {
            $formstring .= "$amp" if ($count > 0);
            $formstring .= "$field=". $self->url_encode_($self->{form_}{$field});
            $count++;
        }
    }

    return ($count>0)?$formstring:'';
}

#----------------------------------------------------------------------------
# register_configuration_item__
#
#     $type            The type of item (configuration, security or chain)
#     $name            Unique name for this item
#     $template        The name of the template to load
#     $object          Reference to the object calling this method
#
# This seemingly innocent method disguises a lot.  It is called by
# modules that wish to register that they have specific elements of UI
# that need to be dynamically added to the Configuration and Security
# screens of POPFile.  This is done so that the HTML module does not
# need to know about the modules that are loaded, their individual
# configuration elements or how to do validation
#
# A module calls this method for each separate UI element (normally an
# HTML form that handles a single configuration option stored in a
# template) and passes in four pieces of information:
#
# The type is the position in the UI where the element is to be
# displayed. configuration means on the Configuration screen under
# "Module Options"; security means on the Security page and is used
# exclusively for stealth mode operation right now; chain is also on
# the security page and is used for identifying chain servers (in the
# case of SMTP the chained server and for POP3 the SPA server)
#
# A unique name for this configuration item
#
# The template (this is the name of a template file and must be unique
# for each call to this method)
#
# A reference to itself.
#
# When this module needs to display an element of UI it will call the
# object's configure_item public method passing in the name of the
# element required, a reference to the loaded template and
# configure_item must set whatever variables are required in the
# template.
#
# When the module needs to validate it will call the object's
# validate_item interface passing in the name of the element, a
# reference to the template and a reference to the form hash which has
# been parsed.
#
# Example the module foo has a configuration item called bar which it
# needs a UI for, and so it calls
#
#    register_configuration_item( 'configuration', 'foo', 'foo-bar.thtml',
#        $self )
#
# later it will receive a call to its
#
#    configure_item( 'foo', loaded foo-bar.thtml, language hash )
#
# and needs to fill the template variables.  Then it will receive a
# call to its
#
#    validate_item( 'foo', loaded foo-bar.thtml, language hash, form hash )
#
# and needs to check the form for information from any form it created
# and returned from the call to configure_item and update its own
# state.
#
#----------------------------------------------------------------------------
sub register_configuration_item__
{
   my ( $self, $type, $name, $templ, $object ) = @_;

   $self->{dynamic_ui__}{$type}{$name}{object}   = $object;
   $self->{dynamic_ui__}{$type}{$name}{template} = $templ;
}

#----------------------------------------------------------------------------
#
# mcount__, ecount__ get the total message count, or the total error count
#
#----------------------------------------------------------------------------

sub mcount__
{
    my ( $self ) = @_;

    my $count = 0;

    my @buckets = $self->{c__}->get_all_buckets( $self->{api_session__} );

    foreach my $bucket (@buckets) {
        $count += $self->get_bucket_parameter__( $bucket, 'count' );
    }

    return $count;
}

sub ecount__
{
    my ( $self ) = @_;

    my $count = 0;

    my @buckets = $self->{c__}->get_all_buckets( $self->{api_session__} );

    foreach my $bucket (@buckets) {
        $count += $self->get_bucket_parameter__( $bucket, 'fncount' );
    }

    return $count;
}

#----------------------------------------------------------------------------
#
# get_bucket_parameter__/set_bucket_parameter__
#
# Wrapper for Classifier::Bayes::get_bucket_parameter__ the eliminates
# the need for all our calls to mention $self->{api_session__}
#
# See Classifier::Bayes::get_bucket_parameter for parameters and
# return values.
#
# (same thing for set_bucket_parameter__)
#
#----------------------------------------------------------------------------
sub get_bucket_parameter__
{

    # The first parameter is going to be a reference to this class, the
    # rest we leave untouched in @_ and pass to the real API

    my $self = shift;

    return $self->{c__}->get_bucket_parameter( $self->{api_session__}, @_ );
}
sub set_bucket_parameter__
{
    my $self = shift;

    return $self->{c__}->set_bucket_parameter( $self->{api_session__}, @_ );
}

# GETTERS/SETTERS

sub classifier
{
    my ( $self, $value ) = @_;

    if ( defined( $value ) ) {
        $self->{c__} = $value;
    }

    return $self->{c__};
}

sub language
{
    my ( $self ) = @_;

    return %{$self->{language__}};
}

sub session_key
{
    my ( $self ) = @_;

    return $self->{session_key__};
}

#----------------------------------------------------------------------------
#
# shutdown_page__
#
#   Determines the text to send in response to a click on the shutdown
#   link.
#
#----------------------------------------------------------------------------
sub shutdown_page__
{
    my ( $self ) = @_;

    # Figure out what style sheet we are using

    my $root = 'skins/' . $self->config_( 'skin' ) . '/';
    my $css_file = $self->get_root_path_( $root . 'style.css' );
    if ( !( -e $css_file ) ) {
        $root = 'skins/default/';
        $css_file = $self->get_root_path_( $root . 'style.css' );
    }

    # Now load the style sheet

    my $css = '<style type="text/css">';
    open CSS, $css_file;
    while ( <CSS> ) {
        $css .= $_;
    }
    close CSS;
    $css .= "</style>";

    # Load the template, set the class of the menu tabs, and send the
    # output to $text

    my $templ = $self->load_template__( 'shutdown-page.thtml' );

    for my $i ( 0..5 ) {
        $templ->param( "Common_Middle_Tab$i" => "menuStandard" );
    }

    my $text = $templ->output();

    # Replace the reference to the favicon, we won't be able to handle
    # that request
    $text =~ s/<link rel="icon" href="favicon\.ico">//;

    # Replace the link to the style sheets with the style sheet itself
    $text =~ s/\Q<link rel="stylesheet" type="text\/css" href="${root}style.css" title="POPFile-Style">\E/$css/;

    # Remove the session key from the menu links:

    $text =~ s/href="(.+?)\?session=.+?"/href="$1"/g;

    return $text;
}

1;
