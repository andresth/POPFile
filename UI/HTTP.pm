#----------------------------------------------------------------------------
#
# This package contains an HTTP server used as a base class for other
# modules that service requests over HTTP (e.g. the UI)
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
package UI::HTTP;

use POPFile::Module;
@ISA = ("POPFile::Module");

use strict;
use warnings;
use locale;

use IO::Socket::INET qw(:DEFAULT :crlf);
use IO::Select;
use Date::Format qw(time2str);

# A handy variable containing the value of an EOL for the network

my $eol = "\015\012";

#----------------------------------------------------------------------------
# new
#
#   Class new() function
#----------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self = POPFile::Module->new();

    bless $self;

    return $self;
}

# ---------------------------------------------------------------------------
#
# start
#
# Called to start the HTTP interface running
#
# ---------------------------------------------------------------------------
sub start
{
    my ( $self ) = @_;
    $self->log_( 1, "Trying to open listening socket on port " . $self->config_('port') . '.' );
    $self->{server_} = IO::Socket::INET->new( Proto     => 'tcp',             # PROFILE BLOCK START
                                    $self->config_( 'local' )  == 1 ? (LocalAddr => 'localhost') : (),
                                     LocalPort => $self->config_( 'port' ),
                                     Listen    => SOMAXCONN,
                                     Reuse     => 1 );                        # PROFILE BLOCK STOP

    if ( !defined( $self->{server_} ) ) {
        my $port = $self->config_( 'port' );
        my $name = $self->name();
        $self->log_( 0, "Couldn't start the $name interface because POPFile could not bind to the listen port $port" );
        print STDERR <<EOM;                                                   # PROFILE BLOCK START

\nCouldn't start the $name interface because POPFile could not bind to the
listen port $port. This could be because there is another service
using that port or because you do not have the right privileges on
your system (On Unix systems this can happen if you are not root
and the port you specified is less than 1024).

EOM
# PROFILE BLOCK STOP

        return 0;
    }

    $self->{selector_} = new IO::Select( $self->{server_} );

    return 1;
}

# ----------------------------------------------------------------------------
#
# stop
#
# Called when the interface must shutdown
#
# ----------------------------------------------------------------------------
sub stop
{
    my ( $self ) = @_;

    close $self->{server_} if ( defined( $self->{server_} ) );
}

# ----------------------------------------------------------------------------
#
# service
#
# Called to handle interface requests
#
# ----------------------------------------------------------------------------
sub service
{
    my ( $self ) = @_;

    my $code = 1;

    return $code if ( !defined( $self->{selector_} ) );

    # See if there's a connection waiting for us, if there is we
    # accept it handle a single request and then exit

    my ( $ready ) = $self->{selector_}->can_read(0);

    # Handle HTTP requests for the UI

    if ( ( defined( $ready ) ) && ( $ready == $self->{server_} ) ) {

        if ( my $client = $self->{server_}->accept() ) {

            # Check that this is a connection from the local machine,
            # if it's not then we drop it immediately without any
            # further processing.  We don't want to allow remote users
            # to admin POPFile

            my ( $remote_port, $remote_host ) = sockaddr_in( $client->peername() );

            if ( ( $self->config_( 'local' ) == 0 ) ||                # PROFILE BLOCK START
                 ( $remote_host eq inet_aton( "127.0.0.1" ) ) ) {     # PROFILE BLOCK STOP

                # Read the request line (GET or POST) from the client
                # and if we manage to do that then read the rest of
                # the HTTP headers grabbing the Content-Length and
                # using it to read any form POST content into $content

                $client->autoflush(1);

                if ( ( defined( $client ) ) &&                      # PROFILE BLOCK START
                     ( my $request = $self->slurp_( $client ) ) ) { # PROFILE BLOCK STOP
                    my $content_length = 0;
                    my $content = '';
                    my $status_code = 200;

                    $self->log_( 2, $request );

                    while ( my $line = $self->slurp_( $client ) )  {
                        $content_length = $1 if ( $line =~ /Content-Length: (\d+)/i );

                        # Discovered that Norton Internet Security was
                        # adding HTTP headers of the form
                        #
                        # ~~~~~~~~~~~~~~: ~~~~~~~~~~~~~
                        #
                        # which we were not recognizing as valid
                        # (surprise, surprise) and this was messing
                        # about our handling of POST data.  Changed
                        # the end of header identification to any line
                        # that does not contain a :

                        last                 if ( $line !~ /:/ );
                    }

                    if ( $content_length > 0 ) {
                        $content = $self->slurp_buffer_( $client,  # PROFILE BLOCK START
                            $content_length );                     # PROFILE BLOCK STOP
                        if ( !defined( $content ) ) {
                            $status_code = 400;
                        } else {
                            $self->log_( 2, $content );
                        }
                    }

                    if ( $status_code != 200 ) {
                        $self->http_error_( $client, $status_code );
                    } else {
                        if ( $request =~ /^(GET|POST) (.*) HTTP\/1\./i ) {
                            $code = $self->handle_url( $client, $2, $1, $content );
                            $self->log_( 2,                                # PROFILE BLOCK START
                                "HTTP handle_url returned code $code\n" ); # PROFILE BLOCK STOP
                        } else {
                            $self->http_error_( $client, 500 );
                        }
                    }
                }
            }

            $self->log_( 2, "Close HTTP connection on $client\n" );
            $self->done_slurp_( $client );
            close $client;
        }
    }

    return $code;
}

# ----------------------------------------------------------------------------
#
# forked
#
# Called when someone forks POPFile
#
# ----------------------------------------------------------------------------
sub forked
{
    my ( $self ) = @_;

    close $self->{server_};
}

# ----------------------------------------------------------------------------
#
# handle_url - Handle a URL request
#
# $client     The web browser to send the results to
# $url        URL to process
# $command    The HTTP command used (GET or POST)
# $content    Any non-header data in the HTTP command
#
# ----------------------------------------------------------------------------
sub handle_url
{
    my ( $self, $client, $url, $command, $content ) = @_;

    return $self->{url_handler_}( $self, $client, $url, $command, $content );
}

# ----------------------------------------------------------------------------
#
# parse_form_    - parse form data and fill in $self->{form_}
#
# $arguments         The text of the form arguments (e.g. foo=bar&baz=fou) or separated by
#                    CR/LF
#
# ----------------------------------------------------------------------------
sub parse_form_
{
    my ( $self, $arguments ) = @_;

    # Normally the browser should have done &amp; to & translation on
    # URIs being passed onto us, but there was a report that someone
    # was having a problem with form arguments coming through with
    # something like http://127.0.0.1/history?session=foo&amp;filter=bar
    # which would mess things up in the argument splitter so this code
    # just changes &amp; to & for safety

    return if ( !defined $arguments );

    $arguments =~ s/&amp;/&/g;

    while ( $arguments =~ m/\G(.*?)=(.*?)(&|\r|\n|$)/g ) {
        my $arg = $1;

        my $need_array = defined( $self->{form_}{$arg} );

        if ( $need_array ) {
            if ( $#{ $self->{form_}{$arg . "_array"} } == -1 ) {
                push( @{ $self->{form_}{$arg . "_array"} }, $self->{form_}{$arg} );
            }
        }

        $self->{form_}{$arg} = $2;
        $self->{form_}{$arg} =~ s/\+/ /g;

        # Expand hex escapes in the form data

        $self->{form_}{$arg} =~ s/%([0-9A-F][0-9A-F])/chr hex $1/gie;

        # Push the value onto an array to allow for multiple values of
        # the same name

        if ( $need_array ) {
            push( @{ $self->{form_}{$arg . "_array"} }, $self->{form_}{$arg} );
        }
    }
}

# ----------------------------------------------------------------------------
#
# url_encode_
#
# $text     Text to encode for URL safety
#
# Encode a URL so that it can be safely passed in a URL as per RFC2396
#
# ----------------------------------------------------------------------------
sub url_encode_
{
    my ( $self, $text ) = @_;

    $text =~ s/ /\+/;
    $text =~ s/([^a-zA-Z0-9_\-.\+\'!~*\(\)])/sprintf("%%%02x",ord($1))/eg;

    return $text;
}

# ----------------------------------------------------------------------------
#
# http_redirect_ - tell the browser to redirect to a url
#
# $client   The web browser to send redirect to
# $url      Where to go
#
# Return a valid HTTP/1.0 header containing a 302 redirect message to the passed in URL
#
# ----------------------------------------------------------------------------
sub http_redirect_
{
    my ( $self, $client, $url ) = @_;

    my $header = "HTTP/1.0 302 Found$eol" .
                 "Location: $url$eol" .
                 "$eol";
    print $client $header;
}

# ----------------------------------------------------------------------------
#
# http_error_ - Output a standard HTTP error message
#
# $client     The web browser to send the results to
# $error      The error number
#
# Return a simple HTTP error message in HTTP 1/0 format
#
# ----------------------------------------------------------------------------
sub http_error_
{
    my ( $self, $client, $error ) = @_;

    $self->log_( 0, "HTTP error $error returned" );

    my $text =      # PROFILE BLOCK START
            "<html><head><title>POPFile Web Server Error $error</title></head>
<body>
<h1>POPFile Web Server Error $error</h1>
An error has occurred which has caused POPFile to return the error $error.
<p>
Click <a href=\"/\">here</a> to continue.
</body>
</html>$eol";       # PROFILE BLOCK STOP

    $self->log_( 1, $text );

    my $error_code = 500;
    $error_code = $error if ( $error =~ /^\d{3}$/ );

    print $client "HTTP/1.0 $error_code Error$eol";
    print $client "Content-Type: text/html$eol";
    print $client "Content-Length: ";
    print $client length( $text );
    print $client "$eol$eol";
    print $client $text;
}

# ----------------------------------------------------------------------------
#
# http_file_ - Read a file from disk and send it to the other end
#
# $client     The web browser to send the results to
# $file       The file to read (always assumed to be a GIF right now)
# $type       Set this to the HTTP return type (e.g. text/html or image/gif)
#
# Returns the contents of a file formatted into an HTTP 200 message or
# an HTTP 404 if the file does not exist
#
# ----------------------------------------------------------------------------
sub http_file_
{
    my ( $self, $client, $file, $type ) = @_;
    my $contents = '';

    if ( defined( $file ) && ( open FILE, "<$file" ) ) {

        binmode FILE;
        while (<FILE>) {
            $contents .= $_;
        }
        close FILE;

        # To prevent the browser for continuously asking for file
        # handled in this way we calculate the current date and time
        # plus 1 hour to give the browser cache 1 hour to keep things
        # like graphics and style sheets in cache.

        my $header = $self->build_http_header_( 200, $type, time + 60 * 60,
                                                length( $contents ) );

        print $client $header . $contents;
    } else {
        $self->http_error_( $client, 404 );
    }
}

# ----------------------------------------------------------------------------
#
# build_http_header_ - 
#
# $status     The status code
# $type       The type of the content
# $expires    The datetime the page cache expires
#             If 0, the page cache will expire instantly
# $length     The length of the content
#
# Returns the header
#
# ----------------------------------------------------------------------------
sub build_http_header_
{
    my ( $self, $status, $type, $expires, $length ) = @_;

    my $date = time2str( "%a, %d %h %Y %X %Z", time, 'GMT' );
    if ( $expires != 0 ) {
        $expires = time2str( "%a, %d %h %Y %X %Z", $expires, 'GMT' );
    }

    my $header = "HTTP/1.0 $status OK$eol" .  # PROFILE BLOCK START
                 "Connection: close$eol" .
                 "Content-Type: $type$eol" .
                 "Date: $date$eol" .
                 "Expires: $expires$eol" .
                 ( $expires eq '0' ?
                   "Pragma: no-cache$eol" .
                   "Cache-Control: no-cache$eol" : '' ) .
                 "Content-Length: $length$eol" .
                 "$eol";                      # PROFILE BLOCK STOP

    return $header;
}

# GETTERS/SETTERS

sub history
{
    my ( $self, $value ) = @_;

    if ( defined( $value ) ) {
        $self->{history__} = $value;
    }

    return $self->{history__};
}

