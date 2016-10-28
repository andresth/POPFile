package Classifier::MailParse;

# ----------------------------------------------------------------------------
#
# MailParse.pm --- Parse a mail message or messages into words
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
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use MIME::Base64;
use MIME::QuotedPrint;

use HTML::Tagset;

# Korean characters definition

my $ksc5601_sym   = '(?:[\xA1-\xAC][\xA1-\xFE])';
my $ksc5601_han   = '(?:[\xB0-\xC8][\xA1-\xFE])';
my $ksc5601_hanja = '(?:[\xCA-\xFD][\xA1-\xFE])';
my $ksc5601       = "(?:$ksc5601_sym|$ksc5601_han|$ksc5601_hanja)";

my $eksc = "(?:$ksc5601|[\x81-\xC6][\x41-\xFE])"; #extended ksc

# These are used for Japanese support

my %encoding_candidates = (                       # PROFILE BLOCK START
    'Nihongo' => [ 'cp932', 'euc-jp', '7bit-jis' ]
);                                                # PROFILE BLOCK STOP

my $ascii              = '[\x00-\x7F]';                                      # ASCII chars
my $two_bytes_euc_jp   = '(?:[\x8E\xA1-\xFE][\xA1-\xFE])';                   # 2bytes EUC-JP chars
my $three_bytes_euc_jp = '(?:\x8F[\xA1-\xFE][\xA1-\xFE])';                   # 3bytes EUC-JP chars
my $euc_jp             = "(?:$ascii|$two_bytes_euc_jp|$three_bytes_euc_jp)"; # EUC-JP chars

# Symbols in EUC-JP chars which cannot be considered a part of words

my $symbol_row1_euc_jp = '(?:[\xA1][\xA1-\xBB\xBD-\xFE])';
my $symbol_row2_euc_jp = '(?:[\xA2][\xA1-\xFE])';
my $symbol_row8_euc_jp = '(?:[\xA8][\xA1-\xFE])';
my $symbol_euc_jp      = "(?:$symbol_row1_euc_jp|$symbol_row2_euc_jp|$symbol_row8_euc_jp)";

# Cho-on kigou(symbol in Japanese), a special symbol which can appear
# in middle of words

my $cho_on_symbol = '(?:\xA1\xBC)';

# Non-symbol EUC-JP chars

my $non_symbol_two_bytes_euc_jp = '(?:[\x8E\xA3-\xA7\xB0-\xFE][\xA1-\xFE])';
my $non_symbol_euc_jp = "(?:$non_symbol_two_bytes_euc_jp|$three_bytes_euc_jp|$cho_on_symbol)";

# Constants for the internal wakachigaki parser.
# Kind of EUC-JP chars
my $euc_jp_symbol    = '[\xA1\xA2\xA6-\xA8\xAD\xF9-\xFC][\xA1-\xFE]';                # The symbols make a word of one character.
my $euc_jp_alphanum  = '(?:\xA3[\xB0-\xB9\xC1-\xDA\xE1-\xFA])+';                     # One or more alphabets and numbers
my $euc_jp_hiragana  = '(?:(?:\xA4[\xA1-\xF3])+(?:\xA1[\xAB\xAC\xB5\xB6\xBC])*)+';   # One or more Hiragana characters
my $euc_jp_katakana  = '(?:(?:\xA5[\xA1-\xF6])+(?:\xA1[\xA6\xBC\xB3\xB4])*)+';       # One or more Katakana characters
my $euc_jp_hkatakana = '(?:\x8E[\xA6-\xDF])+';                                       # One or more Half-width Katakana characters
my $euc_jp_kanji     = '[\xB0-\xF4][\xA1-\xFE](?:[\xB0-\xF4][\xA1-\xFE]|\xA1\xB9)?'; # One or two Kanji characters

my $euc_jp_word = '(' .        # PROFILE BLOCK START
    $euc_jp_alphanum .     '|' . 
    $euc_jp_hiragana .     '|' . 
    $euc_jp_katakana .     '|' . 
    $euc_jp_hkatakana .    '|' . 
    $euc_jp_kanji .        '|' . 
    $euc_jp_symbol .       '|' . 
    $ascii .              '+|' .
    $three_bytes_euc_jp . ')'; # PROFILE BLOCK STOP

# HTML entity mapping to character codes, this maps things like &amp;
# to their corresponding character code

my %entityhash = (           # PROFILE BLOCK START
          'aacute' => 225, 'Aacute' => 193, 'Acirc'  => 194, 'acirc'  => 226,
          'acute'  => 180, 'AElig'  => 198, 'aelig'  => 230, 'Agrave' => 192,
          'agrave' => 224, 'amp'    => 38,  'Aring'  => 197, 'aring'  => 229,
          'atilde' => 227, 'Atilde' => 195, 'Auml'   => 196, 'auml'   => 228,
          'brvbar' => 166, 'ccedil' => 231, 'Ccedil' => 199, 'cedil'  => 184,
          'cent'   => 162, 'copy'   => 169, 'curren' => 164, 'deg'    => 176,
          'divide' => 247, 'Eacute' => 201, 'eacute' => 233, 'ecirc'  => 234,
          'Ecirc'  => 202, 'Egrave' => 200, 'egrave' => 232, 'ETH'    => 208,
          'eth'    => 240, 'Euml'   => 203, 'euml'   => 235, 'frac12' => 189,
          'frac14' => 188, 'frac34' => 190, 'iacute' => 237, 'Iacute' => 205,
          'icirc'  => 238, 'Icirc'  => 206, 'iexcl'  => 161, 'igrave' => 236,
          'Igrave' => 204, 'iquest' => 191, 'iuml'   => 239, 'Iuml'   => 207,
          'laquo'  => 171, 'macr'   => 175, 'micro'  => 181, 'middot' => 183,
          'nbsp'   => 160, 'not'    => 172, 'ntilde' => 241, 'Ntilde' => 209,
          'oacute' => 243, 'Oacute' => 211, 'Ocirc'  => 212, 'ocirc'  => 244,
          'Ograve' => 210, 'ograve' => 242, 'ordf'   => 170, 'ordm'   => 186,
          'oslash' => 248, 'Oslash' => 216, 'Otilde' => 213, 'otilde' => 245,
          'Ouml'   => 214, 'ouml'   => 246, 'para'   => 182, 'plusmn' => 177,
          'pound'  => 163, 'raquo'  => 187, 'reg'    => 174, 'sect'   => 167,
          'shy'    => 173, 'sup1'   => 185, 'sup2'   => 178, 'sup3'   => 179,
          'szlig'  => 223, 'thorn'  => 254, 'THORN'  => 222, 'times'  => 215,
          'Uacute' => 218, 'uacute' => 250, 'ucirc'  => 251, 'Ucirc'  => 219,
          'ugrave' => 249, 'Ugrave' => 217, 'uml'    => 168, 'Uuml'   => 220,
          'uuml'   => 252, 'Yacute' => 221, 'yacute' => 253, 'yen'    => 165,
          'yuml'   => 255 ); # PROFILE BLOCK STOP

# All known HTML tags divided into two groups: tags that generate
# whitespace as in 'foo<br></br>bar' and tags that don't such as
# 'foo<b></b>bar'.  The first case shouldn't count as an empty pair
# because it breaks the line.  The second case doesn't have any visual
# impact and it treated as 'foobar' with an empty pair.

my $spacing_tags = "address|applet|area|base|basefont" . # PROFILE BLOCK START
    "|bdo|bgsound|blockquote|body|br|button|caption" .
    "|center|col|colgroup|dd|dir|div|dl|dt|embed" .
    "|fieldset|form|frame|frameset|h1|h2|h3|h4|h5|h6" .
    "|head|hr|html|iframe|ilayer|input|isindex|label" .
    "|legend|li|link|listing|map|menu|meta|multicol" .
    "|nobr|noembed|noframes|nolayer|noscript|object" .
    "|ol|optgroup|option|p|param|plaintext|pre|script" .
    "|select|spacer|style|table|tbody|td|textarea" .
    "|tfoot|th|thead|title|tr|ul|wbr|xmp";               # PROFILE BLOCK STOP

my $non_spacing_tags = "a|abbr|acronym|b|big|blink" .    # PROFILE BLOCK START
    "|cite|code|del|dfn|em|font|i|img|ins|kbd|q|s" .
    "|samp|small|span|strike|strong|sub|sup|tt|u|var";   # PROFILE BLOCK STOP

my $eol = "\015\012";

#----------------------------------------------------------------------------
# new
#
# Class new() function
#----------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self;

    # Hash of word frequences

    $self->{words__} = {};

    # Total word cout

    $self->{msg_total__} = 0;

    # Internal use for keeping track of a line without touching it

    $self->{ut__} = '';

    # Specifies the parse mode, '' means no color output, if non-zero
    # then color output using a specific session key stored here

    $self->{color__}        = '';
    $self->{color_matrix__} = undef;
    $self->{color_idmap__}  = undef;
    $self->{color_userid__} = undef;

    # This will store the from, to, cc and subject from the last parse
    $self->{from__}    = '';
    $self->{to__}      = '';
    $self->{cc__}      = '';
    $self->{subject__} = '';

    # This is used to store the words found in the from, to, and subject
    # lines for use in creating new magnets, it is a list of pairs mapping
    # a magnet type to a magnet string, e.g. from => popfile@jgc.org

    $self->{quickmagnets__} = {};

    # store the tag that set the foreground/background color so the
    # color can be unset when the tag closes

    $self->{cssfontcolortag__} = '';
    $self->{cssbackcolortag__} = '';

    # This is the distance betwee the back color and the font color
    # as computed using compute_rgb_distance

    $self->{htmlcolordistance__} = 0;

    # This is a mapping between HTML color names and HTML hexadecimal
    # color values used by the map_color value to get canonical color
    # values

    $self->{color_map__} = { # PROFILE BLOCK START
             'aliceblue',            'f0f8ff', 'antiquewhite',      'faebd7',
             'aqua',                 '00ffff', 'aquamarine',        '7fffd4',
             'azure',                'f0ffff', 'beige',             'f5f5dc',
             'bisque',               'ffe4c4', 'black',             '000000',
             'blanchedalmond',       'ffebcd', 'blue',              '0000ff',
             'blueviolet',           '8a2be2', 'brown',             'a52a2a',
             'burlywood',            'deb887', 'cadetblue',         '5f9ea0',
             'chartreuse',           '7fff00', 'chocolate',         'd2691e',
             'coral',                'ff7f50', 'cornflowerblue',    '6495ed',
             'cornsilk',             'fff8dc', 'crimson',           'dc143c',
             'cyan',                 '00ffff', 'darkblue',          '00008b',
             'darkcyan',             '008b8b', 'darkgoldenrod',     'b8860b',
             'darkgray',             'a9a9a9', 'darkgreen',         '006400',
             'darkkhaki',            'bdb76b', 'darkmagenta',       '8b008b',
             'darkolivegreen',       '556b2f', 'darkorange',        'ff8c00',
             'darkorchid',           '9932cc', 'darkred',           '8b0000',
             'darksalmon',           'e9967a', 'darkseagreen',      '8fbc8f',
             'darkslateblue',        '483d8b', 'darkturquoise',     '00ced1',
             'darkviolet',           '9400d3', 'deeppink',          'ff1493',
             'deepskyblue',          '00bfff', 'deepskyblue',       '2f4f4f',
             'dimgray',              '696969', 'dodgerblue',        '1e90ff',
             'firebrick',            'b22222', 'floralwhite',       'fffaf0',
             'forestgreen',          '228b22', 'fuchsia',           'ff00ff',
             'gainsboro',            'dcdcdc', 'ghostwhite',        'f8f8ff',
             'gold',                 'ffd700', 'goldenrod',         'daa520',
             'gray',                 '808080', 'green',             '008000',
             'greenyellow',          'adff2f', 'honeydew',          'f0fff0',
             'hotpink',              'ff69b4', 'indianred',         'cd5c5c',
             'indigo',               '4b0082', 'ivory',             'fffff0',
             'khaki',                'f0e68c', 'lavender',          'e6e6fa',
             'lavenderblush',        'fff0f5', 'lawngreen',         '7cfc00',
             'lemonchiffon',         'fffacd', 'lightblue',         'add8e6',
             'lightcoral',           'f08080', 'lightcyan',         'e0ffff',
             'lightgoldenrodyellow', 'fafad2', 'lightgreen',        '90ee90',
             'lightgrey',            'd3d3d3', 'lightpink',         'ffb6c1',
             'lightsalmon',          'ffa07a', 'lightseagreen',     '20b2aa',
             'lightskyblue',         '87cefa', 'lightslategray',    '778899',
             'lightsteelblue',       'b0c4de', 'lightyellow',       'ffffe0',
             'lime',                 '00ff00', 'limegreen',         '32cd32',
             'linen',                'faf0e6', 'magenta',           'ff00ff',
             'maroon',               '800000', 'mediumaquamarine',  '66cdaa',
             'mediumblue',           '0000cd', 'mediumorchid',      'ba55d3',
             'mediumpurple',         '9370db', 'mediumseagreen',    '3cb371',
             'mediumslateblue',      '7b68ee', 'mediumspringgreen', '00fa9a',
             'mediumturquoise',      '48d1cc', 'mediumvioletred',   'c71585',
             'midnightblue',         '191970', 'mintcream',         'f5fffa',
             'mistyrose',            'ffe4e1', 'moccasin',          'ffe4b5',
             'navajowhite',          'ffdead', 'navy',              '000080',
             'oldlace',              'fdf5e6', 'olive',             '808000',
             'olivedrab',            '6b8e23', 'orange',            'ffa500',
             'orangered',            'ff4500', 'orchid',            'da70d6',
             'palegoldenrod',        'eee8aa', 'palegreen',         '98fb98',
             'paleturquoise',        'afeeee', 'palevioletred',     'db7093',
             'papayawhip',           'ffefd5', 'peachpuff',         'ffdab9',
             'peru',                 'cd853f', 'pink',              'ffc0cb',
             'plum',                 'dda0dd', 'powderblue',        'b0e0e6',
             'purple',               '800080', 'red',               'ff0000',
             'rosybrown',            'bc8f8f', 'royalblue',         '4169e1',
             'saddlebrown',          '8b4513', 'salmon',            'fa8072',
             'sandybrown',           'f4a460', 'seagreen',          '2e8b57',
             'seashell',             'fff5ee', 'sienna',            'a0522d',
             'silver',               'c0c0c0', 'skyblue',           '87ceeb',
             'slateblue',            '6a5acd', 'slategray',         '708090',
             'snow',                 'fffafa', 'springgreen',       '00ff7f',
             'steelblue',            '4682b4', 'tan',               'd2b48c',
             'teal',                 '008080', 'thistle',           'd8bfd8',
             'tomato',               'ff6347', 'turquoise',         '40e0d0',
             'violet',               'ee82ee', 'wheat',             'f5deb3',
             'white',                'ffffff', 'whitesmoke',        'f5f5f5',
             'yellow',               'ffff00', 'yellowgreen',       '9acd32'
    }; # PROFILE BLOCK STOP

    # These store the current HTML background color and font color to
    # detect "invisible ink" used by spammers

    my $result = bless $self, $type;

    $self->{htmlbackcolor__} = $self->map_color( 'white' );
    $self->{htmlbodycolor__} = $self->map_color( 'white' );
    $self->{htmlfontcolor__} = $self->map_color( 'black' );

    $self->{content_type__} = '';
    $self->{base64__}       = '';
    $self->{in_html_tag__}  = 0;
    $self->{html_tag__}     = '';
    $self->{html_arg__}     = '';
    $self->{in_headers__}   = 0;

    # This is used for switching on/off language specific functionality

    $self->{lang__}    = '';
    $self->{first20__} = '';

    # For support Quoted Printable, save encoded text in multiple lines

    $self->{prev__} = '';

    # Object for the Nihongo (Japanese) parser.
    $self->{nihongo_parser__} = undef;

    return $result;
}

# ----------------------------------------------------------------------------
#
# get_color__
#
# Gets the color for the passed in word
#
# $word          The word to check
#
# ----------------------------------------------------------------------------
sub get_color__
{
    my ( $self, $word ) = @_;

    if ( !defined( $self->{color_matrix__} ) ) {
        return $self->{bayes__}->get_color( $self->{color__}, $word );
    } else {
        my $id;

        for my $i ( keys %{ $self->{color_idmap__} } ) {
            if ( $word eq $self->{color_idmap__}{$i} ) {
                $id = $i;
                last;
            }
        }

        if ( defined( $id ) ) {
            my @buckets = $self->{bayes__}->get_buckets( $self->{color__} );

            return $self->{bayes__}->get_bucket_color(   # PROFILE BLOCK START
                $self->{color__},
                $self->{bayes__}->get_top_bucket__(
                    $self->{color_userid__},
                    $id,
                    $self->{color_matrix__},
                    \@buckets ) );                       # PROFILE BLOCK STOP
        } else {
            return 'black';
        }
    }
}

# ----------------------------------------------------------------------------
#
# compute_rgb_distance
#
# Given two RGB colors compute the distance between them by
# considering them as points in 3 dimensions and calculating the
# distance between them (or equivalently the length of a vector
# between them)
#
# $left          One color
# $right         The other color
#
# ----------------------------------------------------------------------------
sub compute_rgb_distance
{
    my ( $self, $left, $right ) = @_;

    # TODO: store front/back colors in a RGB hash/array
    #       converting to a hh hh hh format and back
    #       is a waste as is repeatedly decoding
    #       from hh hh hh format

    # Figure out where the left color is and then subtract the right
    # color (point from it) to get the vector

    $left =~ /^(..)(..)(..)$/;
    my ( $rl, $gl, $bl ) = ( hex( $1 ), hex( $2 ), hex( $3 ) );

    $right =~ /^(..)(..)(..)$/;
    my ( $r, $g, $b ) = ( $rl - hex( $1 ), $gl - hex( $2 ), $bl - hex( $3 ) );

    # Now apply Pythagoras in 3D to get the distance between them, we
    # return the int because we don't need decimal level accuracy

    my $distance = int( sqrt( $r*$r + $g*$g + $b*$b ) );

    print "rgb distance: $left -> $right = $distance" if $self->{debug__};

    return $distance;
}

# ----------------------------------------------------------------------------
#
# compute_html_color_distance
#
# Calls compute_rgb_distance to set up htmlcolordistance__ from the
# current HTML back and font colors
#
# ----------------------------------------------------------------------------
sub compute_html_color_distance
{
    my ( $self ) = @_;

    # TODO: store front/back colors in a RGB hash/array
    #       converting to a hh hh hh format and back
    #       is a waste as is repeatedly decoding
    #       from hh hh hh format

    if ( $self->{htmlfontcolor__} ne '' && $self->{htmlbackcolor__} ne '' ) {
        $self->{htmlcolordistance__} = $self->compute_rgb_distance( # PROFILE BLOCK START
            $self->{htmlfontcolor__}, $self->{htmlbackcolor__} );   # PROFILE BLOCK STOP
    }
}

# ----------------------------------------------------------------------------
#
# map_color
#
# Convert an HTML color value into its canonical lower case
# hexadecimal form with no #
#
# $color        A color value found in a tag
#
# ----------------------------------------------------------------------------
sub map_color
{
    my ( $self, $color ) = @_;

    # The canonical form is lowercase hexadecimal, so start by
    # lowercasing and stripping any initial #

    $color = lc( $color );

    # Map color names to hexadecimal values

    if ( defined( $self->{color_map__}{$color} ) ) {
        return $self->{color_map__}{$color};
    } else {

        # Do this after checking the color map, as there is no "#blue" color
        # TODO: The #, however, is optional in IE.. Do we pseudo-word this?

        $color =~ s/^#//;

        my $old_color = $color;

        # Due to a bug/feature in Microsoft Internet Explorer it's
        # possible to use invalid hexadecimal colors where the number
        # 0 is replaced by any other character and if the hex has an
        # uneven multiple of 3 number of characters it is padded on
        # the right with 0s and if the hex is too long, it is divided
        # into even triplets with the leftmost characters in the
        # triplets being significant. Short (1-char) triplets are
        # left-padded with 0's
        # We go one higher than the quotient if the length isn't an
        # even multiple of 3

        my $quotient = int ( ( length( $color ) + 2 ) / 3 );

        # right-pad entire value to get past the next full multiple of
        # the quotient ("abc abc abc" needs at least one more
        # character to make three even triplets)

        $color .= "00" . "0" x $quotient;

        # even length RGB triplets
        my ( $r, $g, $b ) =                                             # PROFILE BLOCK START
            ( $color =~ /(.{$quotient})(.{$quotient})(.{$quotient})/ ); # PROFILE BLOCK STOP

        print "$r $g $b\n" if $self->{debug__};

        # left-trim very long triplets to 4 bytes
        $r =~ s/.*(.{8})$/$1/;
        $g =~ s/.*(.{8})$/$1/;
        $b =~ s/.*(.{8})$/$1/;

        # right-trim long triplets to get the first two bytes
        $r =~ s/(..).*/$1/;
        $g =~ s/(..).*/$1/;
        $b =~ s/(..).*/$1/;

        # left-pad short triplets (eg FFF -> 0F0F0F)
        $r = '0' . $r if ( length( $r ) == 1 );
        $g = '0' . $g if ( length( $g ) == 1 );
        $b = '0' . $b if ( length( $b ) == 1 );

        $color = "$r$g$b"; # here is our real color value

        # Any non-hex values remaining get 0'd out
        $color =~ s/[^0-9a-f]/0/g;

        if ( $self->{debug__} ) { # PROFILE BLOCK START
            print "hex color $color\n";
            print "flex-hex detected\n" if ( $color ne $old_color );
        }                         # PROFILE BLOCK STOP

        # Add pseudo-word anytime flex hex detected

        if ( $color ne $old_color ) {
            $self->update_pseudoword( 'trick:flexhex', $old_color, 0, '' );
        }

        return $color;
    }
}

# ----------------------------------------------------------------------------
#
# increment_word
#
# Updates the word frequency for a word without performing any
# coloring or transformation on the word
#
# $word     The word
#
# ----------------------------------------------------------------------------
sub increment_word
{
    my ( $self, $word ) = @_;

    $self->{words__}{$word} += 1;
    $self->{msg_total__}    += 1;

    print "--- $word ($self->{words__}{$word})\n" if $self->{debug__};
}

# ----------------------------------------------------------------------------
#
# update_pseudoword
#
# Updates the word frequency for a pseudoword, note that this differs
# from update_word because it does no word mangling
#
# $prefix       The pseudoword prefix (e.g. header)
# $word         The pseudoword (e.g. Mime-Version)
# $encoded      Whether this was found inside encoded text
# $literal      The literal text that generated this pseudoword
#
# Returns 0 if the pseudoword was filtered out by a stopword
#
# ----------------------------------------------------------------------------
sub update_pseudoword
{
    my ( $self, $prefix, $word, $encoded, $literal ) = @_;

    my $mword = $self->{mangle__}->mangle( "$prefix:$word", 1 );

    if ( $mword ne '' ) {
        if ( $self->{color__} ne '' ) {
            if ( $encoded == 1 ) {
                $literal =~ s/</&lt;/g;
                $literal =~ s/>/&gt;/g;
                my $color = $self->get_color__( $mword );
                my $to    = "<b><font color=\"$color\"><a title=\"$mword\">$literal</a></font></b>";
                $self->{ut__} .= $to . ' ';
            }
        }

        $self->increment_word( $mword );
        return 1;
    }

    return 0;
}

# ----------------------------------------------------------------------------
#
# update_word
#
# Updates the word frequency for a word
#
# $word         The word that is being updated
# $encoded      1 if the line was found in encoded text (base64)
# $before       The character that appeared before the word in the original
#               line
# $after        The character that appeared after the word in the original line
# $prefix       A string to prefix any words with in the corpus, used for the
#               special
#               identification of values found in for example the subject line
#
# ----------------------------------------------------------------------------
sub update_word
{
    my ( $self, $word, $encoded, $before, $after, $prefix ) = @_;

    my $mword = $self->{mangle__}->mangle( $word );

    if ( $mword ne '' ) {
        $mword = $prefix . ':' . $mword if ( $prefix ne '' );

        if ( $prefix =~ /(from|to|cc|subject)/i ) {
            push @{ $self->{quickmagnets__}{$prefix} }, $word;
        }

        if ( $self->{color__} ne '' ) {
            my $color = $self->get_color__( $mword );
            if ( $encoded == 0 ) {
                $after = '&' if ( $after eq '>' );
                if ( !( $self->{ut__} =~                                           # PROFILE BLOCK START
                        s/($before)\Q$word\E($after)
                         /$1<b><font color=\"$color\">$word<\/font><\/b>$2/x ) ) { # PROFILE BLOCK STOP
                    print "Could not find $word for colorization\n" if $self->{debug__};
                }
            } else {
                $self->{ut__} .= "<font color=\"$color\">$word<\/font> ";
            }
        }

        $self->increment_word( $mword );
    }
}

# ----------------------------------------------------------------------------
#
# add_line
#
# Parses a single line of text and updates the word frequencies
#
# $bigline      The line to split into words and add to the word counts
# $encoded      1 if the line was found in encoded text (base64)
# $prefix       A string to prefix any words with in the corpus, used for the
#               special identification of values found in for example the
#               subject line
#
# ----------------------------------------------------------------------------
sub add_line
{
    my ( $self, $bigline, $encoded, $prefix ) = @_;
    my $p = 0;

    return if ( !defined( $bigline ) );

    print "add_line: [$bigline]\n" if $self->{debug__};

    # If the line is really long then split at every 1k and feed it to
    # the parser below

    # Check the HTML back and font colors to ensure that we are not
    # about to add words that are hidden inside invisible ink

    if ( $self->{htmlfontcolor__} ne $self->{htmlbackcolor__} ) {

        # If we are adding a line and the colors are different then we
        # will add a count for the color difference to make sure that
        # we catch camouflage attacks using similar colors, if the
        # color similarity is less than 100.  I chose 100 somewhat
        # arbitrarily but classic black text on white background has a
        # distance of 441, red/blue or green on white has distance
        # 255.  100 seems like a reasonable upper bound for tracking
        # evil spammer tricks with similar colors

        if ( $self->{htmlcolordistance__} < 100 ) {
            $self->update_pseudoword(  # PROFILE BLOCK START
                'html', "colordistance$self->{htmlcolordistance__}",
                $encoded, '' );        # PROFILE BLOCK STOP
        }

        while ( $p < length( $bigline ) ) {
            my $line = substr( $bigline, $p, 1024 );

            # mangle up html character entities
            # these are just the low ISO-Latin1 entities
            # see: http://www.w3.org/TR/REC-html32#latin1
            # TODO: find a way to make this (and other similar stuff) highlight
            #       without using the encoded content printer or modifying $self->{ut__}

            while ( $line =~ m/(&(\w{3,6});)/g ) {
                my $from = $1;
                my $to   = $entityhash{$2};

                if ( defined( $to ) ) {

                    # HTML entities confilict with DBCS and EUC-JP
                    # chars. Replace entities with blanks.

                    if ( $self->{lang__} =~ /^(Korean|Nihongo)$/ ) {
                        $to = ' ';
                    } else {
                        $to = chr( $to );
                    }
                    $line         =~ s/$from/$to/g;
                    $self->{ut__} =~ s/$from/$to/g;
                    print "$from -> $to\n" if $self->{debug__};
                }
            }

            while ( $line =~ m/(&#([\d]{1,3});)/g ) {

                # Don't decode odd (nonprintable) characters or < >'s.

                if ( ( ( $2 < 255 ) && ( $2 > 63 ) ) ||  # PROFILE BLOCK START
                     ( $2 == 61 ) ||
                     ( ( $2 < 60 ) && ( $2 > 31 ) ) ) {  # PROFILE BLOCK STOP
                    my $from = $1;
                    my $to   = chr( $2 );

                    if ( defined( $to ) && ( $to ne '' ) ) {
                        $line         =~ s/$from/$to/g;
                        $self->{ut__} =~ s/$from/$to/g;
                        print "$from -> $to\n" if $self->{debug__};
                        $self->update_pseudoword(                       # PROFILE BLOCK START
                            'html', 'numericentity', $encoded, $from ); # PROFILE BLOCK STOP
                    }
                }
            }

            # Pull out any email addresses in the line that are marked
            # with <> and have an @ in them

            while ( $line =~ s/(mailto:)?                      # PROFILE BLOCK START
                               ([[:alpha:]0-9\-_\.]+?
                               @
                               ([[:alpha:]0-9\-_\.]+\.[[:alpha:]0-9\-_]+))
                               ([\"\&\)\?\:\/ >\&\;]|$)//x ) { # PROFILE BLOCK STOP
                $self->update_word( $2, $encoded, ( $1 ? $1 : '' ),  # PROFILE BLOCK START
                                    '[\&\?\:\/ >\&\;]', $prefix );   # PROFILE BLOCK STOP
                $self->add_url( $3, $encoded, '\@', '[\&\?\:\/]', $prefix );
            }

            # Grab domain names (gTLD)
            # http://en.wikipedia.org/wiki/List_of_Internet_top-level_domains

            while ( $line =~ s/(([[:alpha:]0-9\-_]+\.)+)          # PROFILE BLOCK START
                               (aero|arpa|asia|biz|cat|com|coop|edu|gov|info|
                                int|jobs|mil|mobi|museum|name|net|org|pro|tel|
                                travel|xxx)
                               ([^[:alpha:]0-9\-_\.]|$)/$4/ix ) { # PROFILE BLOCK STOP
                $self->add_url( "$1$3", $encoded, '', '', $prefix );
            }

            # Grab country domain names (ccTLD)
            # http://en.wikipedia.org/wiki/List_of_Internet_top-level_domains

            while ( $line =~ s/(([[:alpha:]0-9\-_]+\.)+)            # PROFILE BLOCK START
                               (a[cdefgilmnoqrstuwxz]|
                                b[abdefghijmnorstvwyz]|
                                c[acdfghiklmnorsuvxyz]|
                                d[ejkmoz]|
                                e[cegrstu]|
                                f[ijkmor]|
                                g[abdefghilmnpqrstuwy]|
                                h[kmnrtu]|
                                i[delmnoqrst]|
                                j[emop]|
                                k[eghimnprwyz]|
                                l[abcikrstuvy]|
                                m[acdeghklmnopqrstuvwxyz]|
                                n[acefgilopruz]|
                                om|
                                p[aefghklmnrstwy]|
                                qa|
                                r[eosuw]|
                                s[abcdeghijklmnortuvyz]|
                                t[cdfghjklmnoprtvwz]|
                                u[agksyz]|
                                v[aceginu]|
                                w[fs]|
                                y[et]|
                                z[amw])
                               ([^[:alpha:]0-9\-_\.]|$)/$4/ix )  {  # PROFILE BLOCK STOP
                $self->add_url( "$1$3", $encoded, '', '', $prefix );
            }

            # Grab IP addresses

            while ( $line =~ s/(?<![[:alpha:]\d.])      # PROFILE BLOCK START
                               (([12]?\d{1,2}\.){3}[12]?\d{1,2})
                               (?![[:alpha:]\d])//x ) { # PROFILE BLOCK STOP
                $self->update_word( $1, $encoded, '', '', $prefix );
            }

            # Deal with runs of alternating spaces and letters

            while ( $line =~ s/([ ]|^)                   # PROFILE BLOCK START
                               ([A-Za-z]([\'\*^`&\. ]|[ ][ ])
                                (?:[A-Za-z]\3){1,14}[A-Za-z])
                               ([ ]|\3|[!\?,]|$)/ /x ) { # PROFILE BLOCK STOP
                my $original = "$1$2$4";
                my $word     = $2;
                print "$word ->" if $self->{debug__};
                $word =~ s/[^A-Z]//gi;
                print "$word\n" if $self->{debug__};
                $self->update_word( $word, $encoded, ' ', ' ', $prefix );
                $self->update_pseudoword( 'trick', 'spacedout',  # PROFILE BLOCK START
                                          $encoded, $original ); # PROFILE BLOCK STOP
            }

            # Deal with random insertion of . inside words

            while ( $line =~ s/ ([A-Z]+)\.([A-Z]{2,}) / $1$2 /i ) {
                $self->update_pseudoword( 'trick', 'dottedwords',  # PROFILE BLOCK START
                                          $encoded, "$1$2" );      # PROFILE BLOCK STOP
            }

            if ( $self->{lang__} eq 'Nihongo' ) {

                # In Japanese mode, non-symbol EUC-JP characters should be
                # matched.
                #
                # ^$euc_jp*? is added to avoid incorrect matching.
                # For example, EUC-JP char represented by code A4C8,
                # should not match the middle of two EUC-JP chars
                # represented by CCA4 and C8BE, the second byte of the
                # first char and the first byte of the second char.

                # In Japanese, one character words are common, so care about
                # words between 2 and 45 characters

                while ( $line =~ s/^$euc_jp*?  # PROFILE BLOCK START
                                   ([A-Za-z][A-Za-z\']{2,44}|
                                    $non_symbol_euc_jp{2,45})
                                   (?:[_\-,\.\"\'\)\?!:;\/& \t\n\r]{0,5}|$)
                                  //ox ) {     # PROFILE BLOCK STOP
                    if ( ( $self->{in_headers__} == 0 ) &&    # PROFILE BLOCK START
                         ( $self->{first20count__} < 20 ) ) { # PROFILE BLOCK STOP
                        $self->{first20count__} += 1;
                        $self->{first20__} .= " $1";
                    }

                    $self->update_word(  # PROFILE BLOCK START
                        $1, $encoded, '',
                        '[_\-,\.\"\'\)\?!:;\/ &\t\n\r]|' . $symbol_euc_jp,
                        $prefix );       # PROFILE BLOCK STOP
                }
            } else {
                if ( $self->{lang__} eq 'Korean' ) {

                    # In Korean mode, [[:alpha:]] in regular
                    # expression is changed to 2bytes chars to support
                    # 2 byte characters.
                    #
                    # In Korean, care about words between 2 and 45
                    # characters.

                    while ( $line =~ s/(([A-Za-z]|$eksc)  # PROFILE BLOCK START
                                        ([A-Za-z\']|$eksc){1,44})
                                        ([_\-,\.\"\'\)\?!:;\/& \t\n\r]{0,5}|$)
                                      //x ) {             # PROFILE BLOCK STOP
                        if ( ( $self->{in_headers__} == 0 ) &&    # PROFILE BLOCK START
                             ( $self->{first20count__} < 20 ) ) { # PROFILE BLOCK STOP
                            $self->{first20count__} += 1;
                            $self->{first20__} .= " $1";
                        }

                        $self->update_word( $1, $encoded, '',                # PROFILE BLOCK START
                                            '[_\-,\.\"\'\)\?!:;\/ &\t\n\r]',
                                            $prefix ) if ( length $1 >= 2 ); # PROFILE BLOCK STOP
                    }
                } else {

                    # Only care about words between 3 and 45
                    # characters since short words like an, or, if are
                    # too common and the longest word in English
                    # (according to the OED) is
                    # pneumonoultramicroscopicsilicovolcanoconiosis

                    while ( $line =~ s/([[:alpha:]][[:alpha:]\']{1,44})  # PROFILE BLOCK START
                                       ([_\-,\.\"\'\)\?!:;\/& \t\n\r]{0,5}|$)
                                      //x ) {                            # PROFILE BLOCK STOP
                        if ( ( $self->{in_headers__} == 0 ) &&    # PROFILE BLOCK START
                             ( $self->{first20count__} < 20 ) ) { # PROFILE BLOCK STOP
                            $self->{first20count__} += 1;
                            $self->{first20__} .= " $1";
                        }

                        $self->update_word( $1, $encoded, '',                # PROFILE BLOCK START
                                            '[_\-,\.\"\'\)\?!:;\/ &\t\n\r]',
                                            $prefix ) if ( length $1 >= 3 ); # PROFILE BLOCK STOP
                    }
                }
            }

            $p += 1024;
        }
    } else {
        if ( $bigline =~ /[^ \t]/ ) {
            $self->update_pseudoword( 'trick', 'invisibleink',  # PROFILE BLOCK START
                                      $encoded, $bigline );     # PROFILE BLOCK STOP
        }
    }
}

# ----------------------------------------------------------------------------
#
# update_tag
#
# Extract elements from within HTML tags that are considered important
# 'words' for analysis such as domain names, alt tags,
#
# $tag      The tag name
# $arg      The arguments
# $end_tag  Whether this is an end tag or not
# $encoded  1 if this HTML was found inside encoded (base64) text
#
# ----------------------------------------------------------------------------
sub update_tag
{
    my ( $self, $tag, $arg, $end_tag, $encoded ) = @_;

    # TODO: Make sure $tag only ever gets alphanumeric input (in some
    #       cases it has been demonstrated that things like ()| etc can
    #       end up in $tag

    $tag =~ s/[\r\n]//g;
    $arg =~ s/[\r\n]//g;

    print "HTML " . ( $end_tag ? "closing" : '' ) . " tag $tag with argument $arg\n" if $self->{debug__};

    # End tags do not require any argument decoding but we do look at
    # them to make sure that we handle /font to change the font color

    if ( $end_tag ) {
        if ( $tag =~ /^font$/i ) {
            $self->{htmlfontcolor__} = $self->map_color( 'black' );
            $self->compute_html_color_distance();
        }

        # If we hit a table tag then any font information is lost

        if ( $tag =~ /^(table|td|tr|th)$/i ) {
            $self->{htmlfontcolor__} = $self->map_color( 'black' );
            $self->{htmlbackcolor__} = $self->{htmlbodycolor__};
            $self->compute_html_color_distance();
        }

        if ( lc( $tag ) eq $self->{cssbackcolortag__} ) {
            $self->{htmlbackcolor__}   = $self->{htmlbodycolor__};
            $self->{cssbackcolortag__} = '';

            $self->compute_html_color_distance();

            print "CSS back color reset to $self->{htmlbackcolor__} (tag closed: $tag)\n" if $self->{debug__};
        }

        if ( lc( $tag ) eq $self->{cssfontcolortag__} ) {
            $self->{htmlfontcolor__}   = $self->map_color( 'black' );
            $self->{cssfontcolortag__} = '';

            $self->compute_html_color_distance();

            print "CSS font color reset to $self->{htmlfontcolor__} (tag closed: $tag)\n" if $self->{debug__};
        }

        return;
    }

    # Count the number of TD elements
    if ( $tag =~ /^td$/i ) {
        $self->update_pseudoword( 'html', 'td', $encoded, $tag );
    }

    my $attribute;
    my $value;

    # These are used to pass good values to update_word

    my $quote;
    my $end_quote;

    # Strip the first attribute while there are any attributes
    # Match the closing attribute character, if there is none
    # (this allows nested single/double quotes),
    # match a space or > or EOL

    my $original;

    while ( $arg =~ s/[ \t]*   # PROFILE BLOCK START
                      ((\w+)[ \t]*=[ \t]*
                       (([\"\'])(.*?)\4|([^ \t>]+)($|([ \t>])))
                      )//x ) { # PROFILE BLOCK STOP
        $original  = $1;
        $attribute = $2;
        $value     = $5 || $6 || '';
        $quote     = '';
        $end_quote = '[\> \t\&\n]';
        if ( defined $4 ) {
            $quote     = $4;
            $end_quote = $4;
        }

        print "   attribute $attribute with value $quote$value$quote\n" if $self->{debug__};

        # Remove leading whitespace and leading value-less attributes

        if ( $arg =~ s/^(([ \t]*(\w+)[\t ]+)+)([^=])/$4/ ) {
            print "   attribute(s) $1 with no value\n" if $self->{debug__};
        }

        # Toggle for parsing script URI's.
        # Should be left off (0) until more is known about how different
        # html rendering clients behave.

        my $parse_script_uri = 0;

        # Tags with src attributes

        if ( ( $attribute =~ /^src$/i ) &&                            # PROFILE BLOCK START
             ( ( $tag =~ /^img|frame|iframe$/i ) ||
               ( ( $tag =~ /^script$/i ) && $parse_script_uri ) ) ) { # PROFILE BLOCK STOP

            # "CID:" links refer to an origin-controlled attachment to
            # a html email.  Adding strings from these, even if they
            # appear to be hostnames, may or may not be beneficial

            if ( $value =~ /^(cid)\:/i ) {

                # Add a pseudo-word when CID source links are detected

                $self->update_pseudoword( 'html', 'cidsrc',      # PROFILE BLOCK START
                                          $encoded, $original ); # PROFILE BLOCK STOP

                # TODO: I've seen virus messages try to use a CID: href


            } else {

                my $host = $self->add_url( $value, $encoded,         # PROFILE BLOCK START
                                           $quote, $end_quote, '' ); # PROFILE BLOCK STOP

                # If the host name is not blank (i.e. there was a
                # hostname in the url and it was an image, then if the
                # host was not this host then report an off machine
                # image

                if ( ( $host ne '' ) && ( $tag =~ /^img$/i ) ) {
                    if ( $host ne 'localhost' ) {
                        $self->update_pseudoword( 'html', 'imgremotesrc',  # PROFILE BLOCK START
                                                  $encoded, $original );   # PROFILE BLOCK STOP
                    }
                }

                if ( ( $host ne '' ) && ( $tag =~ /^iframe$/i ) ) {
                    if ( $host ne 'localhost' ) {
                        $self->update_pseudoword( 'html', 'iframeremotesrc',  # PROFILE BLOCK START
                                                  $encoded, $original );      # PROFILE BLOCK STOP
                    }
                }
            }

            next;
        }

        # Tags with href attributes

        if ( ( $attribute =~ /^href$/i ) &&          # PROFILE BLOCK START
             ( $tag =~ /^(a|link|base|area)$/i ) ) { # PROFILE BLOCK STOP

            # Look for mailto:'s

            if ( $value =~ /^mailto:/i ) {
                if ( ( $tag =~ /^a$/ ) &&                        # PROFILE BLOCK START
                     ( $value =~ /^mailto:
                                  ([[:alpha:]0-9\-_\.]+?
                                   @
                                   ([[:alpha:]0-9\-_\.]+?))
                                  ([>\&\?\:\/\" \t]|$)/ix ) )  { # PROFILE BLOCK STOP
                    $self->update_word(                               # PROFILE BLOCK START
                        $1, $encoded, 'mailto:',
                        ( $3 ? '[\\\>\&\?\:\/]' : $end_quote ), '' ); # PROFILE BLOCK STOP
                    $self->add_url(                                 # PROFILE BLOCK START
                        $2, $encoded, '@',
                        ( $3 ? '[\\\&\?\:\/]' : $end_quote ), '' ); # PROFILE BLOCK STOP
                }
            } else {

                # Anything that isn't a mailto is probably an URL

                $self->add_url( $value, $encoded, $quote, $end_quote, '' );
            }

            next;
        }

        # Tags with alt attributes

        if ( ( $attribute =~ /^alt$/i ) && ( $tag =~ /^img$/i ) ) {
            $self->add_line( $value, $encoded, '' );
            next;
        }

        # Tags with working background attributes

        if ( ( $attribute =~ /^background$/i ) &&  # PROFILE BLOCK START
             ( $tag =~ /^(td|table|body)$/i ) ) {  # PROFILE BLOCK STOP
            $self->add_url( $value, $encoded, $quote, $end_quote, '' );
            next;
        }

        # Tags that load sounds

        if ( $attribute =~ /^bgsound$/i && $tag =~ /^body$/i ) {
            $self->add_url( $value, $encoded, $quote, $end_quote, '' );
            next;
        }

        # Tags with colors in them

        if ( ( $attribute =~ /^color$/i ) && ( $tag =~ /^font$/i ) ) {
            $self->update_word( $value, $encoded, $quote, $end_quote, '' );
            $self->update_pseudoword( 'html', "fontcolor$value",  # PROFILE BLOCK START
                                      $encoded, $original );      # PROFILE BLOCK STOP
            $self->{htmlfontcolor__} = $self->map_color( $value );
            $self->compute_html_color_distance();
            print "Set html font color to $self->{htmlfontcolor__}\n" if $self->{debug__};
            next;
        }

        if ( ( $attribute =~ /^text$/i ) && ( $tag =~ /^body$/i ) ) {
            $self->update_pseudoword( 'html', "fontcolor$value",  # PROFILE BLOCK START
                                      $encoded, $original );      # PROFILE BLOCK STOP
            $self->update_word( $value, $encoded, $quote, $end_quote, '' );
            $self->{htmlfontcolor__} = $self->map_color( $value );
            $self->compute_html_color_distance();
            print "Set html font color to $self->{htmlfontcolor__}\n" if $self->{debug__};
            next;
        }

        # The width and height of images

        if ( ( $attribute =~ /^(width|height)$/i ) && ( $tag =~ /^img$/i ) ) {
            $attribute = lc( $attribute );
            $self->update_pseudoword( 'html', "img$attribute$value",  # PROFILE BLOCK START
                                      $encoded, $original );          # PROFILE BLOCK STOP
            next;
        }

        # Font sizes

        if ( ( $attribute =~ /^size$/i ) && ( $tag =~ /^font$/i ) ) {

            # TODO: unify font size scaling to use the same scale
            #       across size specifiers

            $self->update_pseudoword( 'html', "fontsize$value",  # PROFILE BLOCK START
                                      $encoded, $original );     # PROFILE BLOCK STOP
            next;
        }

        # Tags with background colors

        if ( ( $attribute =~ /^(bgcolor|back)$/i ) &&        # PROFILE BLOCK START
             ( $tag =~ /^(td|table|body|tr|th|font)$/i ) ) { # PROFILE BLOCK STOP
            $self->update_word( $value, $encoded, $quote, $end_quote, '' );
            $self->update_pseudoword( 'html', "backcolor$value",  # PROFILE BLOCK START
                                      $encoded, $original );      # PROFILE BLOCK STOP
            $self->{htmlbackcolor__} = $self->map_color( $value );
            print "Set html back color to $self->{htmlbackcolor__}\n" if $self->{debug__};

            if ( $tag =~ /^body$/i ) {
                $self->{htmlbodycolor__} = $self->{htmlbackcolor__}
            }
            $self->compute_html_color_distance();
            next;
        }

        # Tags with a charset

        if ( ( $attribute =~ /^content$/i ) && ( $tag =~ /^meta$/i ) ) {
            if ( $value =~ /charset=([^\t\r\n ]{1,40})[\"\>]?/ ) {
                $self->update_word( $1, $encoded, '', '', '' );
            }
            next;
        }

        # CSS handling

        if ( !exists( $HTML::Tagset::emptyElement->{ lc( $tag ) } ) &&  # PROFILE BLOCK START
             ( $attribute =~ /^style$/i ) ) {                           # PROFILE BLOCK STOP
            print "      Inline style tag found in $tag: $attribute=$value\n" if $self->{debug__};

            my $style = $self->parse_css_style( $value );

            if ( $self->{debug__} ) { # PROFILE BLOCK START
                print "      CSS properties: ";
                foreach my $key ( keys( %{$style} ) ) {
                    print "$key($style->{$key}), ";
                }
                print "\n";
            }                         # PROFILE BLOCK STOP

            # CSS font sizing
            if ( defined( $style->{'font-size'} ) ) {

                my $size = $style->{'font-size'};

                # TODO: unify font size scaling to use the same scale
                #       across size specifiers approximate font sizes here:
                # http://www.dejeu.com/web/tools/tech/css/variablefontsizes.asp

                if ( $size =~ /(((\+|\-)?\d?\.?\d+)  # PROFILE BLOCK START
                                (em|ex|px|%|pt|in|cm|mm|pt|pc))|
                               (xx-small|x-small|small|medium|large|x-large|
                                xx-large)/x ) {      # PROFILE BLOCK STOP
                    $self->update_pseudoword( 'html', "cssfontsize$size",  # PROFILE BLOCK START
                                              $encoded, $original );       # PROFILE BLOCK STOP
                    print "     CSS font-size set to: $size\n" if $self->{debug__};
                }
            }

            # CSS visibility
            if ( defined( $style->{'visibility'} ) ) {
                $self->update_pseudoword(                # PROFILE BLOCK START
                    'html', "cssvisibility" . $style->{'visibility'},
                    $encoded, $original );               # PROFILE BLOCK STOP
            }

            # CSS display
            if ( defined( $style->{'display'} ) ) {
                $self->update_pseudoword(                # PROFILE BLOCK START
                    'html', "cssdisplay" . $style->{'display'},
                    $encoded, $original );               # PROFILE BLOCK STOP
            }


            # CSS foreground coloring

            if ( defined( $style->{'color'} ) ) {
                my $color = $style->{'color'};

                print "      CSS color: $color\n" if $self->{debug__};

                $color = $self->parse_css_color( $color );

                if ( $color ne "error" ) {
                    $self->{htmlfontcolor__} = $color;
                    $self->compute_html_color_distance();

                    print "      CSS set html font color to $self->{htmlfontcolor__}\n" if $self->{debug__};
                    $self->update_pseudoword(  # PROFILE BLOCK START
                        'html', "cssfontcolor$self->{htmlfontcolor__}",
                        $encoded, $original ); # PROFILE BLOCK STOP

                    $self->{cssfontcolortag__} = lc( $tag );
                }
            }

            # CSS background coloring

            if ( defined( $style->{'background-color'} ) ) {

                my $background_color = $style->{'background-color'};

                $background_color =                              # PROFILE BLOCK START
                    $self->parse_css_color( $background_color ); # PROFILE BLOCK STOP

                if ( $background_color ne "error" ) {
                    $self->{htmlbackcolor__} = $background_color;
                    $self->compute_html_color_distance();
                    print "       CSS set html back color to $self->{htmlbackcolor__}\n" if $self->{debug__};

                    $self->{htmlbodycolor__} = $background_color  # PROFILE BLOCK START
                        if ( $tag =~ /^body$/i );                 # PROFILE BLOCK STOP
                    $self->{cssbackcolortag__} = lc( $tag );

                    $self->update_pseudoword(  # PROFILE BLOCK START
                        'html', "cssbackcolor$self->{htmlbackcolor__}",
                        $encoded, $original ); # PROFILE BLOCK STOP
                }
            }

            # CSS all-in one background declaration (ugh)

            if ( defined( $style->{'background'} ) ) {
                my $expression;
                my $background = $style->{'background'};

                # Take the possibly multi-expression "background" property

                while ( $background =~ s/^([^ \t\r\n\f]+)( |$)// ) {

                    # and examine each expression individually

                    $expression = $1;
                    print "       CSS expression $expression in background property\n" if $self->{debug__};

                    my $background_color =                     # PROFILE BLOCK START
                        $self->parse_css_color( $expression ); # PROFILE BLOCK STOP

                    # to see if it is a color

                    if ( $background_color ne "error" ) {
                        $self->{htmlbackcolor__} = $background_color;
                        $self->compute_html_color_distance();
                        print "       CSS set html back color to $self->{htmlbackcolor__}\n" if $self->{debug__};

                        if ( $tag =~ /^body$/i ) {
                            $self->{htmlbodycolor__} = $background_color;
                        }
                        $self->{cssbackcolortag__} = lc( $tag );

                        $self->update_pseudoword(  # PROFILE BLOCK START
                            'html', "cssbackcolor$self->{htmlbackcolor__}",
                            $encoded, $original ); # PROFILE BLOCK STOP
                    }
                }
            }
        }

        # TODO: move this up into the style part above

        # Tags with style attributes (this one may impact
        # performance!!!)  most container tags accept styles, and the
        # background style may not be in a predictable location
        # (search the entire value)

        if ( ( $attribute =~ /^style$/i ) &&                    # PROFILE BLOCK START
             ( $tag =~ /^(body|td|tr|table|span|div|p)$/i ) ) { # PROFILE BLOCK STOP
            $self->add_url( $1, $encoded, '[\']', '[\']', '' )                           # PROFILE BLOCK START
                if ( $value =~ /background\-image:[ \t]?url\([ \t]?\'(.*)\'[ \t]?\)/i ); # PROFILE BLOCK STOP
            next;
        }

        # Tags with action attributes

        if ( $attribute =~ /^action$/i && $tag =~ /^form$/i ) {
            if ( $value =~ /^(ftp|http|https):\/\//i ) {
                $self->add_url( $value, $encoded, $quote, $end_quote, '' );
                next;
            }

            # mailto forms

            if ( $value =~ /^mailto:                     # PROFILE BLOCK START
                            ([[:alpha:]0-9\-_\.]+?
                             @
                             ([[:alpha:]0-9\-_\.]+?))
                            ([>\&\?\:\/\" \t]|$)/ix )  { # PROFILE BLOCK STOP
                $self->update_word(                               # PROFILE BLOCK START
                    $1, $encoded, 'mailto:',
                    ( $3 ? '[\\\>\&\?\:\/]' : $end_quote ), '' ); # PROFILE BLOCK STOP
                $self->add_url(                                   # PROFILE BLOCK START
                    $2, $encoded, '@',
                    ( $3 ? '[\\\>\&\?\:\/]' : $end_quote ), '' ); # PROFILE BLOCK STOP
            }
            next;
        }
    }
}

# ----------------------------------------------------------------------------
#
# add_url
#
# Parses a single url or domain and identifies interesting parts
#
# $url          the domain name to handle
# $encoded      1 if the domain was found in encoded text (base64)
# $before       The character that appeared before the URL in the original line
# $after        The character that appeared after the URL in the original line
# $prefix       A string to prefix any words with in the corpus, used for the
#               special identification of values found in for example the
#               subject line
# $noadd        If defined indicates that only parsing should be done, no
#               word updates
#
# Returns the hostname
#
# ----------------------------------------------------------------------------
sub add_url
{
    my ( $self, $url, $encoded, $before, $after, $prefix, $noadd ) = @_;

    my $temp_url = $url;
    my $temp_before;
    my $temp_after;
    my $hostform;   #ip or name

    # parts of a URL, from left to right
    my $protocol;
    my $authinfo;
    my $host;
    my $port;
    my $path;
    my $query;
    my $hash;

    return undef if ( !defined( $url ) );

    # Strip the protocol part of a URL (e.g. http://)

    $protocol = $1 if ( $url =~ s/^([^:]*)\:\/\/// );

    # Remove any URL encoding (protocol may not be URL encoded)

    my $oldurl   = $url;
    my $percents = ( $url =~ s/(%([0-9A-Fa-f]{2}))/chr(hex("0x$2"))/ge );

    if ( ( $percents > 0 ) && !defined( $noadd ) ) {
        $self->update_pseudoword( 'html', 'encodedurl', $encoded, $oldurl );
    }

    # Extract authorization information from the URL
    # (e.g. http://foo@bar.com)

    if ( $url =~ s/^(([[:alpha:]0-9\-_\.\;\:\&\=\+\$\,]+)(\@|\%40))+// ) {
        $authinfo = $1;

        if ( $authinfo ne '' ) {
            $self->update_pseudoword( 'html', 'authorization', 
                                      $encoded, $oldurl );
        }
    }

    if ( $url =~ s/^(([[:alpha:]0-9\-_]+\.)+)          # PROFILE BLOCK START
                    (aero|arpa|asia|biz|cat|com|coop|edu|gov|info|
                     int|jobs|mil|mobi|museum|name|net|org|pro|tel|
                     travel|xxx|[a-z]{2})
                    ([^[:alpha:]0-9\-_\.]|$)/$4/ix ) { # PROFILE BLOCK STOP
        $host     = "$1$3";
        $hostform = "name";
    } else {
        if ( $url =~ /(([^:\/])+)/ ) {

            # Some other hostname format found, maybe
            # Read here for reference: http://www.pc-help.org/obscure.htm
            # Go here for comparison: http://www.samspade.org/t/url

            # save the possible hostname

            my $host_candidate = $1;

            # stores discovered IP address

            my %quads;

            # temporary values

            my $quad = 1;
            my $number;

            # iterate through the possible hostname, build dotted quad
            # format

            while ( $host_candidate =~                                # PROFILE BLOCK START
                    s/\G^((0x)[0-9A-Fa-f]+|0[0-7]+|[0-9]+)(\.)?// ) { # PROFILE BLOCK STOP
                my $hex = $2;

                # possible IP quad(s)

                my $quad_candidate = $1;
                my $more_dots      = $3;

                if ( defined $hex ) {

                    # hex number
                    # trim arbitrary octets that are greater than most
                    # significant bit

                    $quad_candidate =~ s/.*(([0-9A-F][0-9A-F]){4})$/$1/i;
                    $number = hex( $quad_candidate );
                } else {
                    if ( $quad_candidate =~ /^0([0-7]+)/ ) {

                        # octal number

                        $number = oct( $1 );
                    } else {

                        # assume decimal number
                        # deviates from the obscure.htm document here,
                        # no current browsers overflow

                        $number = int( $quad_candidate );
                    }
                }

                # No more IP dots?

                if ( !defined( $more_dots ) ) {

                    # Expand final decimal/octal/hex to extra quads

                    while ( $quad <= 4 ) {
                        my $shift = ( ( 4 - $quad ) * 8 );
                        $quads{$quad} =       # PROFILE BLOCK START
                            ( $number & ( hex( "0xFF" ) << $shift ) )
                                >> $shift;    # PROFILE BLOCK STOP
                        $quad += 1;
                    }
                } else {

                    # Just plug the quad in, no overflow allowed

                    $quads{$quad} = $number if ( $number < 256 );
                    $quad += 1;
                }

                last if ( $quad > 4 );
            }

            $host_candidate =~ s/\r|\n|$//g;
            if ( ( $host_candidate eq '' ) &&  # PROFILE BLOCK START
                 defined( $quads{1} )      &&
                 defined( $quads{2} )      &&
                 defined( $quads{3} )      &&
                 defined( $quads{4} )      &&
                 !defined( $quads{5} ) ) {     # PROFILE BLOCK STOP

                # we did actually find an IP address, and not some fake

                $hostform = "ip";
                $host     = "$quads{1}.$quads{2}.$quads{3}.$quads{4}";
                $url =~ s/(([^:\/])+)//;
            }
        }
    }

    if ( !defined( $host ) || ( $host eq '' ) ) {
        print "no hostname found: [$temp_url]\n" if $self->{debug__};
        return '';
    }

    $port  = $1 if ( $url =~ s/^\:(\d+)// );
    $path  = $1 if ( $url =~ s/^([\\\/][^\#\?\n]*)($)?// );
    $query = $1 if ( $url =~ s/^[\?]([^\#\n]*|$)?// );
    $hash  = $1 if ( $url =~ s/^[\#](.*)$// );

    if ( !defined( $protocol ) || ( $protocol =~ /^(http|https)$/ ) ) {
        $temp_before = $before;
        $temp_before = "\:\/\/" if ( defined $protocol );
        $temp_before = "[\@]" if ( defined $authinfo );

        $temp_after = $after;
        $temp_after = "[\#]" if ( defined $hash );
        $temp_after = "[\?]" if ( defined $query );
        $temp_after = "[\\\\\/]" if ( defined $path );
        $temp_after = "[\:]" if ( defined $port );

        # add the entire domain

        $self->update_word(                                                 # PROFILE BLOCK START
            $host, $encoded,
            $temp_before, $temp_after, $prefix ) if ( !defined( $noadd ) ); # PROFILE BLOCK STOP

        # decided not to care about tld's beyond the verification
        # performed when grabbing $host special subTLD's can just get
        # their own classification weight (eg, .bc.ca)
        # http://www.0dns.org has a good reference of ccTLD's and
        # their sub-tld's if desired

        if ( $hostform eq 'name' ) {

            # recursively add the roots of the domain

            while ( $host =~ s/^([^\.]+\.)?(([^\.]+\.?)*)(\.[^\.]+)$/$2$4/ ) {

                if ( !defined( $1 ) ) {
                    $self->update_word(                                # PROFILE BLOCK START
                        $4, $encoded,
                        $2, '[<]', $prefix) if ( !defined( $noadd ) ); # PROFILE BLOCK STOP
                    last;
                }
                $self->update_word(                                      # PROFILE BLOCK START
                    $host, $encoded,
                    $1 || $2, '[<]', $prefix) if ( !defined( $noadd ) ); # PROFILE BLOCK STOP
            }
        }
    }

    # $protocol $authinfo $host $port $query $hash may be processed
    # below if desired
    return $host;
}

# ----------------------------------------------------------------------------
#
# parse_html
#
# Parse a line that might contain HTML information, returns 1 if we
# are still inside an unclosed HTML tag
#
# $line     A line of text
# $encoded  1 if this HTML was found inside encoded (base64) text
#
# ----------------------------------------------------------------------------
sub parse_html
{
    my ( $self, $line, $encoded ) = @_;

    my $found = 1;

    $line =~ s/[\r\n]+/ /gm;

    print "parse_html: [$line] " . $self->{in_html_tag__} . "\n" if $self->{debug__};

    # Remove HTML comments and other tags that begin !

    while ( $line =~ s/(<!.*?>)// ) {
        $self->update_pseudoword( 'html', 'comment', $encoded, $1 );
        print "$line\n" if $self->{debug__};
    }

    # Remove invalid tags.  This finds tags of the form [a-z0-9]+ with
    # optional attributes and removes them if the tag isn't
    # recognized.

    # TODO: This also removes tags in plain text emails so a sentence
    # such as 'To run the program type "program <filename>".' is also
    # effected.  The correct fix seams to be to look at the
    # Content-Type header and only process mails of type text/html.

    while ( $line =~ s/(<\/?(?!(?:$spacing_tags|$non_spacing_tags)\W)  # PROFILE BLOCK START
                        [a-z0-9]+(?:\s+.*?)?\/?>)//iox ) {             # PROFILE BLOCK STOP
        $self->update_pseudoword( 'html', 'invalidtag', $encoded, $1 );
        print "html:invalidtag: $1\n" if $self->{debug__};
    }

    # Remove pairs of non-spacing tags without content such as <b></b>
    # and also <b><i></i></b>.

    # TODO: What about combined open and close tags such as <b />?

    while ( $line =~ s/(<($non_spacing_tags)(?:\s+[^>]*?)?><\/\2>)//io ) {
        $self->update_pseudoword( 'html', 'emptypair', $encoded, $1 );
        print "html:emptypair: $1\n" if $self->{debug__};
    }

    while ( $found && ( $line ne '' ) ) {
        $found = 0;

        # If we are in an HTML tag then look for the close of the tag,
        # if we get it then handle the tag, if we don't then keep
        # building up the arguments of the tag

        if ( $self->{in_html_tag__} ) {
            if ( $line =~ s/^([^>]*?)>// ) {
                $self->{html_arg__} .= $1;
                $self->{in_html_tag__} = 0;
                $self->{html_tag__} =~ s/=\n ?//g;
                $self->{html_arg__} =~ s/=\n ?//g;
                $self->update_tag( $self->{html_tag__}, $self->{html_arg__},  # PROFILE BLOCK START
                                   $self->{html_end}, $encoded );             # PROFILE BLOCK STOP
                $self->{html_tag__} = '';
                $self->{html_arg__} = '';
                $found              = 1;
                next;
            } else {
                $self->{html_arg__} .= $line;
                return 1;
            }
        }

        # Does the line start with a HTML tag that is closed (i.e. has
        # both the < and the > present)?  If so then handle that tag
        # immediately and continue

        if ( $line =~ s/^<([\/]?)([A-Za-z]+)([^>]*?)>// ) {
            $self->update_tag( $2, $3, ( $1 eq '/' ), $encoded );
            $found = 1;
            next;
        }

        # Does the line consist of just a tag that has no closing >
        # then set up the global vars that record the tag and return 1
        # to indicate to the caller that we have an unclosed tag

        if ( $line =~ /^<([\/]?)([A-Za-z][^ >]+)([^>]*)$/ ) {
            $self->{html_end}      = ( $1 eq '/' );
            $self->{html_tag__}    = $2;
            $self->{html_arg__}    = $3;
            $self->{in_html_tag__} = 1;
            return 1;
        }

        # There could be something on the line that needs parsing
        # (such as a word), if we reach here then we are not in an
        # unclosed tag and so we can grab everything from the start of
        # the line to the end or the first < and pass it to the line
        # parser

        if ( $line =~ s/^([^<]+)(<|$)/$2/ ) {
            $found = 1;
            $self->add_line( $1, $encoded, '' );
        }
    }

    return 0;
}

# ----------------------------------------------------------------------------
#
# parse_file
#
# Read messages from file and parse into a list of words and
# frequencies, returns a colorized HTML version of message if color is
# set
#
# $file     The file to open and parse
# $max_size The maximum size of message to parse, or 0 for unlimited
# $reset    If set to 0 then the list of words from a previous parse is not
#           reset, this can be used to do multiple parses and build a single
#           word list.  By default this is set to 1 and the word list is reset
#
# ----------------------------------------------------------------------------
sub parse_file
{
    my ( $self, $file, $max_size, $reset ) = @_;

    $reset    = 1 if ( !defined( $reset    ) );
    $max_size = 0 if ( !defined( $max_size ) || ( $max_size =~ /\D/ ) );

    $self->start_parse( $reset );

    my $size_read = 0;

    open MSG, "<$file";
    binmode MSG;

    # Read each line and find each "word" which we define as a
    # sequence of alpha characters

    while ( <MSG> ) {
        $size_read += length( $_ );
        $self->parse_line( $_ );
        if ( ( $max_size > 0 ) &&           # PROFILE BLOCK START
             ( $size_read > $max_size ) ) { # PROFILE BLOCK STOP
            last;
        }
    }

    close MSG;

    $self->stop_parse();

    if ( $self->{color__} ne '' ) {
        $self->{colorized__} .= $self->{ut__} if ( $self->{ut__} ne '' );

        $self->{colorized__} .= "</tt>";
        $self->{colorized__} =~ s/(\r\n\r\n|\r\r|\n\n)/__BREAK____BREAK__/g;
        $self->{colorized__} =~ s/[\r\n]+/__BREAK__/g;
        $self->{colorized__} =~ s/__BREAK__/<br \/>/g;

        return $self->{colorized__};
    } else {
        return '';
    }
}

# ----------------------------------------------------------------------------
#
# start_parse
#
# Called to reset internal variables before parsing.  This is
# automatically called when using the parse_file API, and must be
# called before the first call to parse_line.
#
# $reset    If set to 0 then the list of words from a previous parse is not
#           reset, this can be used to do multiple parses and build a single
#           word list.  By default this is set to 1 and the word list is reset
#
# ----------------------------------------------------------------------------
sub start_parse
{
    my ( $self, $reset ) = @_;

    $reset = 1 if ( !defined( $reset ) );

    # This will contain the mime boundary information in a mime message

    $self->{mime__} = '';

    # Contains the encoding for the current block in a mime message

    $self->{encoding__} = '';

    # Variables to save header information to while parsing headers

    $self->{header__}   = '';
    $self->{argument__} = '';

    # Clear the word hash

    $self->{content_type__} = '';

    # Base64 attachments are loaded into this as we read them

    $self->{base64__} = '';

    # Variable to note that the temporary colorized storage is
    # "frozen", and what type of freeze it is (allows nesting of
    # reasons to freeze colorization)

    $self->{in_html_tag__} = 0;

    $self->{html_tag__}    = '';
    $self->{html_arg__}    = '';

    if ( $reset ) {
        $self->{words__} = {};
    }

    $self->{msg_total__}    = 0;
    $self->{from__}         = '';
    $self->{to__}           = '';
    $self->{cc__}           = '';
    $self->{subject__}      = '';
    $self->{ut__}           = '';
    $self->{quickmagnets__} = {};

    $self->{htmlbodycolor__} = $self->map_color( 'white' );
    $self->{htmlbackcolor__} = $self->map_color( 'white' );
    $self->{htmlfontcolor__} = $self->map_color( 'black' );
    $self->compute_html_color_distance();

    $self->{in_headers__} = 1;

    $self->{first20__}      = '';
    $self->{first20count__} = 0;

    # Used to return a colorize page

    $self->{colorized__} = '';
    $self->{colorized__} .= "<tt>" if ( $self->{color__} ne '' );

    # Clear the character set to avoid using the wrong charsets
    $self->{charset__} = '';

    if ( $self->{lang__} eq 'Nihongo' ) {

        # Since Text::Kakasi is not thread-safe, we use it under the
        # control of a Mutex to avoid a crash if we are running on
        # Windows.
        if ( $self->{need_kakasi_mutex__} ) {
            require POPFile::Mutex;
            $self->{kakasi_mutex__}->acquire();
        }

        # Initialize Nihongo (Japanese) parser
        $self->{nihongo_parser__}{init}( $self );
    }
}

# ----------------------------------------------------------------------------
#
# stop_parse
#
# Called at the end of a parse job.  Automatically called if
# parse_file is used, must be called after the last call to
# parse_line.
#
# ----------------------------------------------------------------------------
sub stop_parse
{
    my ( $self ) = @_;

    $self->{colorized__} .= $self->clear_out_base64();

    $self->clear_out_qp();

    # If we reach here and discover that we think that we are in an
    # unclosed HTML tag then there has probably been an error (such as
    # a < in the text messing things up) and so we dump whatever is
    # stored in the HTML tag out

    if ( $self->{in_html_tag__} ) {
        $self->add_line( "$self->{html_tag__} $self->{html_arg__}", 0, '' );
    }

    # if we are here, and still have headers stored, we must have a
    # bodyless message

    # TODO: Fix me

    if ( $self->{header__} ne '' ) {
        $self->parse_header( $self->{header__}, $self->{argument__},  # PROFILE BLOCK START
                             $self->{mime__}, $self->{encoding__} );  # PROFILE BLOCK STOP
        $self->{header__}   = '';
        $self->{argument__} = '';
    }

    $self->{in_html_tag__} = 0;

    if ( $self->{lang__} eq 'Nihongo' ) {

        # Close Nihongo (Japanese) parser
        $self->{nihongo_parser__}{close}( $self );

        if ( $self->{need_kakasi_mutex__} ) {
            require POPFile::Mutex;
            $self->{kakasi_mutex__}->release();
        }
    }
}

# ----------------------------------------------------------------------------
#
# parse_line
#
# Called to parse a single line from a message.  If using this API
# directly then be sure to call start_parse before the first call to
# parse_line.
#
# $line               Line of file to parse
#
# ----------------------------------------------------------------------------
sub parse_line
{
    my ( $self, $read ) = @_;

    if ( $read ne '' ) {

        # For the Mac we do further splitting of the line at the CR
        # characters

        while ( $read =~ s/(.*?)[\r\n]+// ) {
            my $line = "$1\r\n";

            next if ( !defined( $line ) );

            print ">>> $line" if $self->{debug__};

            # Decode quoted-printable

            if ( !$self->{in_headers__} &&                           # PROFILE BLOCK START
                 ( $self->{encoding__} =~ /quoted\-printable/i ) ) { # PROFILE BLOCK STOP
                if ( $line =~ s/=\r\n$// ) {

                    # Encoded in multiple lines

                    $self->{prev__} .= $line;
                    next;
                } else {
                    $line = $self->{prev__} . $line;
                    $self->{prev__} = '';
                }
                $line = decode_qp( $line );
                $line =~ s/\x00/NUL/g;
            }

            if ( ( $self->{lang__} eq 'Nihongo' ) &&      # PROFILE BLOCK START
                 !$self->{in_headers__} &&
                 ( $self->{encoding__} !~ /base64/i ) ) { # PROFILE BLOCK STOP

                # Decode \x??
                $line =~ s/\\x([8-9A-F][A-F0-9])/pack("C", hex($1))/eig;

                $line = convert_encoding(                           # PROFILE BLOCK START
                    $line, $self->{charset__}, 'euc-jp', '7bit-jis',
                    @{ $encoding_candidates{ $self->{lang__} } } ); # PROFILE BLOCK STOP
                $line = $self->{nihongo_parser__}{parse}( $self, $line );
            }

            if ( $self->{color__} ne '' ) {

                if ( !$self->{in_html_tag__} ) {
                    $self->{colorized__} .= $self->{ut__};
                    $self->{ut__} = '';
                }

                $self->{ut__} .= $self->splitline( $line,                 # PROFILE BLOCK START
                                                   $self->{encoding__} ); # PROFILE BLOCK STOP
            }

            if ( $self->{in_headers__} ) {

                # temporary colorization while in headers is handled
                # within parse_header

                $self->{ut__} = '';

                # Check for blank line signifying end of headers

                if ( $line =~ /^(\r\n|\r|\n)/ ) {

                    # Parse the last header
                    ( $self->{mime__}, $self->{encoding__} ) =      # PROFILE BLOCK START
                        $self->parse_header(
                            $self->{header__}, $self->{argument__},
                            $self->{mime__}, $self->{encoding__} ); # PROFILE BLOCK STOP

                    # Clear the saved headers
                    $self->{header__}   = '';
                    $self->{argument__} = '';

                    $self->{ut__} .= $self->splitline( "\015\012", 0 );
                    $self->{ut__} .= "<a name=\"message_body\" />";

                    $self->{in_headers__} = 0;
                    print "Header parsing complete.\n" if $self->{debug__};

                    next;
                }

                # Append to argument if the next line begins with
                # whitespace (isn't a new header)

                if ( $line =~ /^([\t ])([^\r\n]+)/ ) {
                    $self->{argument__} .= "$eol$1$2";
                    next;
                }

                # If we have an email header then split it into the
                # header and its argument

                if ( $line =~ /^([A-Za-z\-]+):[ \t]*([^\n\r]*)/ ) {

                    # Parse the last header

                    ( $self->{mime__}, $self->{encoding__} ) =   # PROFILE BLOCK START
                        $self->parse_header(
                            $self->{header__}, $self->{argument__},
                            $self->{mime__}, $self->{encoding__} )
                        if ( $self->{header__} ne '' );          # PROFILE BLOCK STOP

                    # Save the new information for the current header

                    $self->{header__}   = $1;
                    $self->{argument__} = $2;
                    next;
                }

                next;
            }

            # If we are in a mime document then spot the boundaries

            if ( ( $self->{mime__} ne '' ) &&                     # PROFILE BLOCK START
                 ( $line =~ /^\-\-($self->{mime__})(\-\-)?/ ) ) { # PROFILE BLOCK STOP

                # approach each mime part with fresh eyes

                $self->{encoding__} = '';

                if ( !defined( $2 ) ) {

                    # This means there was no trailing -- on the mime
                    # boundary (which would have indicated the end of
                    # a boundary, so now we have a new part of the
                    # document, hence we need to look for new headers

                    print "Hit MIME boundary --$1\n" if $self->{debug__};

                    $self->clear_out_qp();

                    # Decode base64 for every part.
                    $self->{colorized__} .= $self->clear_out_base64() . "\n\n";

                    $self->{in_headers__} = 1;
                } else {

                    # A boundary was just terminated

                    $self->{in_headers__} = 0;

                    my $boundary = $1;

                    print "Hit MIME boundary terminator --$1--\n" if $self->{debug__};

                    # Escape to match escaped boundary characters

                    $boundary =~ s/(.*)/\Q$1\E/g;

                    # Remove the boundary we just found from the
                    # boundary list.  The list is stored in
                    # $self->{mime__} and consists of mime boundaries
                    # separated by the alternation characters | for
                    # use within a regexp

                    my $temp_mime = '';

                    foreach my $aboundary ( split( /\|/, $self->{mime__} ) ) {
                        if ( $boundary ne $aboundary ) {
                            if ( $temp_mime ne '' ) {
                                $temp_mime = join( '|',                      # PROFILE BLOCK START
                                                   $temp_mime, $aboundary ); # PROFILE BLOCK STOP
                            } else {
                                $temp_mime = $aboundary;
                            }
                        }
                    }

                    $self->{mime__} = $temp_mime;

                    print "MIME boundary list now $self->{mime__}\n" if $self->{debug__};
                }

                next;
            }

            # If we are doing base64 decoding then look for suitable
            # lines and remove them for decoding

            if ( $self->{encoding__} =~ /base64/i ) {
                $line =~ s/[\r\n]//g;
                $line =~ s/!$//;
                $self->{base64__} .= $line;

                next;
            }

            next if ( !defined( $line ) );

            $self->parse_html( $line, 0 );
        }
    }
}

# ----------------------------------------------------------------------------
#
# clear_out_base64
#
# If there's anything in the {base64__} then decode it and parse it,
# returns colorization information to be added to the colorized output
#
# ----------------------------------------------------------------------------
sub clear_out_base64
{
    my ( $self ) = @_;

    my $colorized = '';

    if ( $self->{base64__} ne '' ) {
        my $decoded = '';

        $self->{ut__}     = '' if ( $self->{color__} ne '' );
        $self->{base64__} =~ s/ //g;

        print "Base64 data: " . $self->{base64__} . "\n" if $self->{debug__};

        $decoded = decode_base64( $self->{base64__} );

        if ( $self->{lang__} eq 'Nihongo' ) {
            $decoded = convert_encoding(                        # PROFILE BLOCK START
                $decoded, $self->{charset__}, 'euc-jp', '7bit-jis',
                @{ $encoding_candidates{ $self->{lang__} } } ); # PROFILE BLOCK STOP
            $decoded = $self->{nihongo_parser__}{parse}( $self, $decoded );
        }

        $self->parse_html( $decoded, 1 );

        print "Decoded: " . $decoded . "\n" if $self->{debug__};

        if ( $self->{color__} ne '' ) {
            $self->{ut__} = "<b>Found in encoded data:</b> " . $self->{ut__};
        }

        if ( $self->{color__} ne '' ) {
            if ( $self->{ut__} ne '' ) {
                $colorized = $self->{ut__};
                $self->{ut__} = '';
            }
        }
    }

    $self->{base64__} = '';

    return $colorized;
}

# ----------------------------------------------------------------------------
#
# clear_out_qp
#
# If there's anything in the {prev__} then decode it and parse it
#
# ----------------------------------------------------------------------------
sub clear_out_qp
{
    my ( $self ) = @_;

    if ( ( $self->{encoding__} =~ /quoted\-printable/i ) &&
         ( $self->{prev__} ne '' ) ) {
        my $line = decode_qp( $self->{prev__} );
        $line =~ s/\x00/NUL/g;

        if ( $self->{lang__} eq 'Nihongo' ) {
            $line = convert_encoding(
                $line, $self->{charset__}, 'euc-jp', '7bit-jis',
                @{ $encoding_candidates{ $self->{lang__} } } );
            $line = $self->{nihongo_parser__}{parse}( $self, $line );
        }

        $self->{ut__} .= $self->splitline( $line, '' );

        $self->parse_html( $line, 0 );
        $self->{prev__} = '';
    }
}

# ----------------------------------------------------------------------------
#
# decode_string - Decode MIME encoded strings used in the header lines
# in email messages
#
# $mystring     - The string that neeeds decode
#
# Return the decoded string, this routine recognizes lines of the form
#
# =?charset?[BQ]?text?=
#
# $lang Pass in the current interface language for language specific
# encoding conversion A B indicates base64 encoding, a Q indicates
# quoted printable encoding
# ----------------------------------------------------------------------------
sub decode_string
{
    # I choose not to use "$mystring = MIME::Base64::decode( $1 );"
    # because some spam mails have subjects like: "Subject: adjpwpekm
    # =?ISO-8859-1?Q?=B2=E1=A4=D1=AB=C7?= dopdalnfjpw".  Therefore we
    # proceed along the string, from left to right, building a new
    # string from the decoded and non-decoded parts

    my ( $self, $mystring, $lang ) = @_;

    my $charset = '';

    return '' if ( !defined( $mystring ) );

    $lang = $self->{lang__} if ( !defined( $lang ) || ( $lang eq '' ) );

    my $output          = '';
    my $last_is_encoded = 0;

    while ( $mystring =~ m/(.*?)(=\?([\w-]+)\?(B|Q)\?(.*?)\?=)/igc ) {
        my ( $pre, $atom, $encoding, $value );
        ( $pre, $atom, $charset, $encoding, $value ) = ( $1, $2, $3, $4, $5 );

        $output .= $pre unless ( $last_is_encoded && defined( $atom ) # PROFILE BLOCK START
                                    && ( $pre =~ /^[\t ]+$/ ) );      # PROFILE BLOCK STOP( Per RFC 2047 section 6.2 )

        if ( defined( $atom ) ) {
            if ( $encoding =~ /^[bB]$/ ) {
                $value = decode_base64( $value );

                # for Japanese header

                if ( $lang eq 'Nihongo' ) {
                    $value = convert_encoding(                          # PROFILE BLOCK START
                        $value, $charset, 'euc-jp', '7bit-jis',
                        @{ $encoding_candidates{ $self->{lang__} } } ); # PROFILE BLOCK STOP
                }
                $last_is_encoded = 1;
            } elsif ( $encoding =~ /^[qQ]$/ ) {
                $value =~ s/\_/=20/g;
                $value = decode_qp( $value );
                $value =~ s/\x00/NUL/g;

                # for Japanese header

                if ( $lang eq 'Nihongo' ) {
                    $value = convert_encoding(                          # PROFILE BLOCK START
                        $value, $charset, 'euc-jp', '7bit-jis',
                        @{ $encoding_candidates{ $self->{lang__} } } ); # PROFILE BLOCK STOP
                }
                $last_is_encoded = 1;
            }
        } else {
            $last_is_encoded = 0;
        }
        $output .= $value || '';
    }

    # grab the unmatched tail (thanks to /gc and \G)

    $output .= $1 if ( $mystring =~ m/\G(.*)/g );

    return $output;
}

# ----------------------------------------------------------------------------
#
# get_header - Returns the value of the from, to, subject or cc header
#
# $header      Name of header to return (note must be lowercase)
#
# ----------------------------------------------------------------------------
sub get_header
{
    my ( $self, $header ) = @_;

    return $self->{ $header . '__' } || '';
}

# ----------------------------------------------------------------------------
#
# parse_header - Performs parsing operations on a message header
#
# $header       Name of header being processed
# $argument     Value of header being processed
# $mime         The presently saved mime boundaries list
# $encoding     Current message encoding
#
# ----------------------------------------------------------------------------
sub parse_header
{
    my ( $self, $header, $argument, $mime, $encoding ) = @_;

    print "Header ($header) ($argument)\n" if $self->{debug__};

    # After a discussion with Tim Peters and some looking at emails
    # I'd received I discovered that the header names (case sensitive)
    # are very significant in identifying different types of mail, for
    # example much spam uses MIME-Version, MiME-Version and
    # Mime-Version

    my $fix_argument = $argument;
    $fix_argument =~ s/</&lt;/g;
    $fix_argument =~ s/>/&gt;/g;

    $argument =~ s/(\r\n|\r|\n)//g;
    $argument =~ s/^[ \t]+//;

    if ( $self->update_pseudoword( 'header', $header, 0, $header ) ) {
        if ( $self->{color__} ne '' ) {
            my $color     = $self->get_color__( "header:$header" );
            $self->{ut__} = "<b><font color=\"$color\">$header</font></b>: $fix_argument\015\012";
        }
    } else {
        if ( $self->{color__} ne '' ) {
            $self->{ut__} = "$header: $fix_argument\015\012";
        }
    }

    # Check the encoding type in all RFC 2047 encoded headers

    if ( $argument =~ /=\?([^\r\n\t ]{1,40})\?(Q|B)/i ) {
        $self->update_word( $1, 0, '', '', 'charset' );
    }

    # Handle the From, To and Cc headers and extract email addresses
    # from them and treat them as words

    # For certain headers we are going to mark them specially in the
    # corpus by tagging them with where they were found to help the
    # classifier do a better job.  So if you have
    #
    # From: foo@bar.com
    #
    # then we'll add from:foo@bar.com to the corpus and not just
    # foo@bar.com

    my $prefix = '';

    if ( $header =~ /^(From|To|Cc|Reply\-To)$/i ) {

        # These headers at least can be decoded

        $argument = $self->decode_string( $argument, $self->{lang__} );

        if ( $header =~ /^From$/i ) {
            $prefix = 'from';
            if ( $self->{from__} eq '' ) {
                $self->{from__} = $argument;
                $self->{from__} =~ s/[\t\r\n]//g;
            }
        }

        if ( $header =~ /^To$/i ) {
            $prefix = 'to';
            if ( $self->{to__} eq '' ) {
                $self->{to__} = $argument;
                $self->{to__} =~ s/[\t\r\n]//g;
            }
        }

        if ( $header =~ /^Cc$/i ) {
            $prefix = 'cc';
            if ( $self->{cc__} eq '' ) {
                $self->{cc__} = $argument;
                $self->{cc__} =~ s/[\t\r\n]//g;
            }
        }

        while ( $argument =~ s/<([[:alpha:]0-9\-_\.]+?@([[:alpha:]0-9\-_\.]+?))>// ) {
            $self->update_word( $1, 0, ';', '&', $prefix );
            $self->add_url( $2, 0, '@', '[&<]', $prefix );
        }

        while ( $argument =~ s/([[:alpha:]0-9\-_\.]+?@([[:alpha:]0-9\-_\.]+))// ) {
            $self->update_word( $1, 0, '', '', $prefix );
            $self->add_url( $2, 0, '@', '', $prefix );
        }

        $self->add_line( $argument, 0, $prefix );
        return ( $mime, $encoding );
    }

    if ( $header =~ /^Subject$/i ) {

        $prefix = 'subject';
        $argument = $self->decode_string( $argument, $self->{lang__} );
        if ( $self->{subject__} eq '' ) {

            # In Japanese mode, parse subject with Nihongo (Japanese) parser

            $argument = $self->{nihongo_parser__}{parse}( $self, $argument )    # PROFILE BLOCK START
                if ( ( $self->{lang__} eq 'Nihongo' ) && ( $argument ne '' ) ); # PROFILE BLOCK STOP

            $self->{subject__} = $argument;
            $self->{subject__} =~ s/[\t\r\n]//g;
        }
    }

    $self->{date__} = $argument if ( $header =~ /^Date$/i );

    if ( $header =~ /^X-Spam-Status$/i ) {

        # We have found a header added by SpamAssassin. We expect to
        # find keywords in here that will help us classify our
        # messages

        # We will find the keywords after the phrase "tests=" and
        # before SpamAssassin's version number or autolearn= string

        ( my $sa_keywords = $argument ) =~ s/[\r\n ]//sg;
        $sa_keywords =~ s/^.+tests=(.+)/$1/;
        $sa_keywords =~ s/(.+)autolearn.+$/$1/ or  # PROFILE BLOCK START
            $sa_keywords =~ s/(.+)version.+$/$1/;  # PROFILE BLOCK STOP

        # remove all spaces that may still be present:
        $sa_keywords =~ s/[\t ]//g;

        foreach ( split /,/, $sa_keywords ) {
            $self->update_pseudoword( 'spamassassin', lc( $_ ), 0, $argument );
        }
    }

    if ( $header =~ /^X-SpamViper-Score$/ ) {

        # This is a header that was added by SpamViper. Works just
        # like the SpamAssassin header.

        ( my $sv_keywords = $argument ) =~ s/[\r\n]//g;

        # The keywords can be found after the phrase "Mail scored X
        # points":

        $sv_keywords =~ s/Mail scored \d+ points //;
        $sv_keywords =~ s/[\t ]//g;

        foreach ( split /,/, $sv_keywords ) {
            $self->update_pseudoword( 'spamviper', lc( $_ ), 0, $argument );
        }
    }

    if ( $header =~ /^X-Spam-Level$/i ) {
        my $count = ( $argument =~ tr/*// );
        for ( 1 .. $count ) {
            $self->update_pseudoword( 'spamassassinlevel', 'spam',  # PROFILE BLOCK START
                                      0, $argument );               # PROFILE BLOCK STOP
        }
    }

    # Look for MIME

    if ( $header =~ /^Content-Type$/i ) {
        if ( $argument =~ /charset=\"?([^\"\r\n\t ]{1,40})\"?/ ) {
            $self->{charset__} = $1;
            $self->update_word( $1, 0, '', '', 'charset' );
        }

        if ( $argument =~ /^(.*?)(;)/ ) {
            print "Set content type to $1\n" if $self->{debug__};
            $self->{content_type__} = $1;
        }

        if ( $argument =~ /multipart\//i ) {
            my $boundary = $argument;

            if ( $boundary =~ /boundary=[ ]?      # PROFILE BLOCK START
                               (\"([A-Z0-9\'\(\)\+\_\,\-\.\/\:\=\?]
                                   [A-Z0-9\'\(\)\+_,\-\.\/:=\? \@]{0,69})\"|
                                ([^\(\)\<\>\@\,\;\:\\\"\/\[\]\?\=]{1,70})
                               )/ix ) {           # PROFILE BLOCK STOP

                $boundary = ( $2 || $3 );

                $boundary =~ s/(.*)/\Q$1\E/g;

                if ( $mime ne '' ) {

                    # Fortunately the pipe character isn't a valid
                    # mime boundary character!

                    $mime = join( '|', $mime, $boundary );
                } else {
                    $mime = $boundary;
                }
                print "Set mime boundary to $mime\n" if $self->{debug__};
                return ( $mime, $encoding );
            }
        }

        if ( $argument =~ /name=\"(.*)\"/i ) {
            $self->add_attachment_filename( $1 );
        }

        return ( $mime, $encoding );
    }

    # Look for the different encodings in a MIME document, when we hit
    # base64 we will do a special parse here since words might be
    # broken across the boundaries

    if ( $header =~ /^Content-Transfer-Encoding$/i ) {
        $encoding = $argument;
        print "Setting encoding to $encoding\n" if $self->{debug__};
        my $compact_encoding = $encoding;
        $compact_encoding =~ s/[^A-Za-z0-9]//g;
        $self->update_pseudoword( 'encoding', $compact_encoding,  # PROFILE BLOCK START
                                  0, $encoding );                 # PROFILE BLOCK STOP
        return ( $mime, $encoding );
    }

    # Some headers to discard

    return ( $mime, $encoding )                                     # PROFILE BLOCK START
        if ( $header =~ /^(Thread-Index|X-UIDL|Message-ID|
                           X-Text-Classification|X-Mime-Key)$/ix ); # PROFILE BLOCK STOP

    # Some headers should never be RFC 2047 decoded

    $argument = $self->decode_string( $argument, $self->{lang__} )            # PROFILE BLOCK START
        if ( $header !~ /^(Received|Content\-Type|Content\-Disposition)$/i ); # PROFILE BLOCK STOP

    if ( $header =~ /^Content-Disposition$/i ) {
        $self->handle_disposition( $argument );
        return ( $mime, $encoding );
    }

    $self->add_line( $argument, 0, $prefix );

    return ( $mime, $encoding );
}

# ----------------------------------------------------------------------------
#
# parse_css_ruleset - Parses text for CSS declarations
#                     Uses the second part of the "ruleset" grammar
#
# $line         The line to match
# $braces       1 if braces are included, 0 if excluded. Defaults to 0.
#               (optional)
# Returns       A hash of properties containing their expressions
#
# ----------------------------------------------------------------------------

sub parse_css_style
{
    my ( $self, $line, $braces ) = @_;

    # http://www.w3.org/TR/CSS2/grammar.html

    $braces = 0 if ( !defined( $braces ) );

    # A reference is used to return data

    my $hash = {};

    if ( $braces ) {
        $line =~ s/\{(.*?)\}/$1/;
    }
    while ( $line =~ s/^[ \t\r\n\f]*                              # PROFILE BLOCK START
                       ([a-z][a-z0-9\-]+)[ \t\r\n\f]*:
                       [ \t\r\n\f]*(.*?)[ \t\r\n\f]?(;|$)//ix ) { # PROFILE BLOCK STOP
        $hash->{ lc( $1 ) } = $2;
    }
    return $hash;
}

# ----------------------------------------------------------------------------
#
# parse_css_color - Parses a CSS color string
#
# $color        The string to parse
# Returns       (r,g,b) triplet in list context, rrggbb (hex) color in scalar
#               context
#
# In case of an error: (-1,-1,-1) in list context, "error" in scalar
# context
#
# ----------------------------------------------------------------------------

sub parse_css_color
{
    my ( $self, $color ) = @_;

    # CSS colors can be in a rgb(r,g,b), #hhh, #hhhhhh or a named color form

    # http://www.w3.org/TR/CSS2/syndata.html#color-units

    my ( $r, $g, $b, $error, $found ) = ( 0, 0, 0, 0, 0 );

    if ( $color =~ /^rgb\( ?(.*?) ?\, ?(.*?) ?\, ?(.*?) ?\)$/ ) {

        # rgb(r,g,b) can be expressed as values 0-255 or percentages 0%-100%,
        # numbers outside this range are allowed and should be clipped into
        # this range

        # TODO: store front/back colors in a RGB hash/array
        #       converting to a hh hh hh format and back
        #       is a waste as is repeatedly decoding
        #       from hh hh hh format

        ( $r, $g, $b ) = ( $1, $2, $3 );

        my $ispercent = 0;

        my $value_re   = qr/^((-[1-9]\d*)|([1-9]\d*|0))$/;
        my $percent_re = qr/^([1-9]\d+|0)%$/;

        my ( $r_temp, $g_temp, $b_temp );

        if ( ( ($r_temp) = ($r =~ $percent_re) ) &&  # PROFILE BLOCK START
             ( ($g_temp) = ($g =~ $percent_re) ) &&
             ( ($b_temp) = ($b =~ $percent_re) ) ) { # PROFILE BLOCK STOP

            $ispercent = 1;

            # clip to 0-100
            $r_temp = 100 if ( $r_temp > 100 );
            $g_temp = 100 if ( $g_temp > 100 );
            $b_temp = 100 if ( $b_temp > 100 );

            # convert into 0-255 range
            $r = int( ( ( $r_temp / 100 ) * 255 ) + .5 );
            $g = int( ( ( $g_temp / 100 ) * 255 ) + .5 );
            $b = int( ( ( $b_temp / 100 ) * 255 ) + .5 );

            $found = 1;
        }

        if ( ( $r =~ $value_re ) &&  # PROFILE BLOCK START
             ( $g =~ $value_re ) &&
             ( $b =~ $value_re ) ) { # PROFILE BLOCK STOP

            $ispercent = 0;

            #clip to 0-255

            $r =   0 if ( $r <=   0 );
            $r = 255 if ( $r >= 255 );
            $g =   0 if ( $g <=   0 );
            $g = 255 if ( $g >= 255 );
            $b =   0 if ( $b <=   0 );
            $b = 255 if ( $b >= 255 );

            $found = 1;
        }

        if ( !$found ) {

            # here we have a combination of percentages and integers
            # or some other oddity
            $ispercent = 0;
            $error     = 1;
        }

        print "        CSS rgb($r, $g, $b) percent: $ispercent\n" if $self->{debug__};
    }
    if ( $color =~ /^#(([0-9a-f]{3})|([0-9a-f]{6}))$/i ) {

        # #rgb or #rrggbb
        print "        CSS numeric form: $color\n" if $self->{debug__};

        $color = $2 || $3;

        if ( defined( $2 ) ) {

            # in 3 value form, the value is computed by doubling each digit

            ( $r, $g, $b ) = ( hex( $1 x 2 ), hex( $2 x 2 ), hex( $3 x 2 ) )  # PROFILE BLOCK START
                if ( $color =~ /^(.)(.)(.)$/ );                               # PROFILE BLOCK STOP
        } else {
            ( $r, $g, $b ) = ( hex( $1 ), hex( $2 ), hex( $3 ) )  # PROFILE BLOCK START
                if ( $color =~ /^(..)(..)(..)$/ );                # PROFILE BLOCK STOP
        }
        $found = 1;

    }
    if ( $color =~ /^(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|  # PROFILE BLOCK START
                      olive|purple|red|silver|teal|white|yellow)$/i ) {     # PROFILE BLOCK STOP

        # these are the only CSS defined colours

        print "       CSS textual color form: $color\n" if $self->{debug__};

        my $new_color = $self->map_color( $color );

        # our color map may have failed

        $error = 1 if ( $new_color eq $color );
        ( $r, $g, $b ) = ( hex( $1 ), hex( $2 ), hex( $3 ) )  # PROFILE BLOCK START
            if ( $new_color =~ /^(..)(..)(..)$/ );            # PROFILE BLOCK STOP
        $found = 1;
    }

    $found = 0 if ( $error );

    if ( $found &&                                         # PROFILE BLOCK START
         defined( $r ) && ( 0 <= $r ) && ( $r <= 255 ) &&
         defined( $g ) && ( 0 <= $g ) && ( $g <= 255 ) &&
         defined( $b ) && ( 0 <= $b ) && ( $b <= 255 ) ) { # PROFILE BLOCK STOP
        if ( wantarray ) {
            return ( $r, $g, $b );
        } else {
            $color = sprintf( '%1$02x%2$02x%3$02x', $r, $g, $b );
            return $color;
        }
    } else {
        if ( wantarray ) {
            return ( -1, -1, -1 );
        } else {
            return "error";
        }
    }
}

# ----------------------------------------------------------------------------
#
# match_attachment_filename - Matches a line like 'attachment;
# filename="<filename>"
#
# $line         The line to match
# Returns       The first match (= "attchment" if found)
#               The second match (= name of the file if found)
#
# ----------------------------------------------------------------------------
sub match_attachment_filename
{
    my ( $self, $line ) = @_;

    $line =~ /\s*(.*);\s*filename=\"(.*)\"/;

    return ( $1, $2 );
}

# ----------------------------------------------------------------------------
#
# file_extension - Splits a filename into name and extension
#
# $filename     The filename to split
# Returns       The name of the file
#               The extension of the file
#
# ----------------------------------------------------------------------------
sub file_extension
{
    my ( $self, $filename ) = @_;

    if ( $filename =~ m/(.*)\.(.*)$/ ) {
        return ( $1, $2 );
    } else {
        return ( $filename, '' );
    }
}

# ----------------------------------------------------------------------------
#
# add_attachment_filename - Adds a file name and extension as pseudo
#                           words attchment_name and attachment_ext
#
# $filename     The filename to add to the list of words
#
# ----------------------------------------------------------------------------
sub add_attachment_filename
{
    my ( $self, $filename ) = @_;

    if ( defined( $filename ) && ( $filename ne '' ) ) {
        print "Add filename $filename\n" if $self->{debug__};

        # Decode the filename
        $filename = $self->decode_string( $filename );

        my ( $name, $ext ) = $self->file_extension( $filename );

        if ( defined( $name ) && ( $name ne '' ) ) {
            $self->update_pseudoword( 'mimename', $name, 0, $name );
        }

        if ( defined( $ext ) && ( $ext ne '' ) ) {
            $self->update_pseudoword( 'mimeextension', $ext, 0, $ext );
        }
    }
}

# ----------------------------------------------------------------------------
#
# handle_disposition - Parses Content-Disposition header to extract filename.
#                      If filename found, at the file name and extension to
#                      the word list
#
# $params     The parameters of the Content-Disposition header
#
# ----------------------------------------------------------------------------
sub handle_disposition
{
    my ( $self, $params ) = @_;

    my ( $attachment, $filename ) = $self->match_attachment_filename( $params );

    if ( defined( $attachment ) && ( $attachment eq 'attachment' ) ) {
        $self->add_attachment_filename( $filename );
    }
}

# ----------------------------------------------------------------------------
#
# splitline - Escapes characters so a line will print as plain-text
#             within a HTML document.
#
# $line         The line to escape
# $encoding     The value of any current encoding scheme
#
# ----------------------------------------------------------------------------
sub splitline
{
    my ( $self, $line, $encoding ) = @_;

    $line =~ s/([^\r\n]{100,120} )/$1\r\n/g;
    $line =~ s/([^ \r\n]{120})/$1\r\n/g;

    $line =~ s/</&lt;/g;
    $line =~ s/>/&gt;/g;

    if ( $encoding =~ /quoted\-printable/i ) {
        $line =~ s/=3C/&lt;/g;
        $line =~ s/=3E/&gt;/g;
    }

    $line =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;

    return $line;
}

# GETTERS/SETTERS

sub first20
{
    my ( $self ) = @_;

    return $self->{first20__};
}

sub quickmagnets
{
    my ( $self ) = @_;

    return $self->{quickmagnets__};
}

sub mangle
{
    my ( $self, $value ) = @_;

    $self->{mangle__} = $value;
}

# ----------------------------------------------------------------------------
#
# convert_encoding
#
# Convert string from one encoding to another
#
# $string       The string to be converted
# $from         Original encoding
# $to           The encoding which the string is converted to
# $default      The default encoding that is used when $from is invalid or not
#               defined
# @candidates   Candidate encodings for guessing
# ----------------------------------------------------------------------------
sub convert_encoding
{
    my ( $string, $from, $to, $default, @candidates ) = @_;

    # If the string contains only ascii characters, do nothing.
    return $string if ( $string =~ /^[\r\n\t\x20-\x7E]*$/ );

    require Encode;
    require Encode::Guess;

    # First, guess the encoding.

    my $enc = Encode::Guess::guess_encoding( $string, @candidates );

    if ( ref $enc ) {
        $from = $enc->name;
    } else {

        # If guess does not work, check whether $from is valid.

        if ( !( Encode::resolve_alias( $from ) ) ) {

            # Use $default as $from when $from is invalid.

            $from = $default;
        }
    }

    if ( $from ne $to ) {
        my ( $orig_string ) = $string;

        # Workaround for Encode::Unicode error bug.
        eval {
            no warnings 'utf8';
            if ( ref $enc ) {
                $string = Encode::encode( $to, $enc->decode( $string ) );
            } else {
                Encode::from_to( $string, $from, $to );
            }
        };
        $string = $orig_string if ( $@ );
    }
    return $string;
}

# ----------------------------------------------------------------------------
#
# parse_line_with_kakasi
#
# Parse a line with Kakasi
#
# Japanese needs to be parsed by language processing filter, "Kakasi"
# before it is passed to Bayes classifier because words are not
# splitted by spaces.
#
# $line          The line to be parsed
#
# ----------------------------------------------------------------------------
sub parse_line_with_kakasi
{
    my ( $self, $line ) = @_;

    # If the line does not contain Japanese characters, do nothing
    return $line if ( $line =~ /^[\x00-\x7F]*$/ );

    # Split Japanese line into words using Kakasi Wakachigaki mode
    $line = Text::Kakasi::do_kakasi( $line );

    return $line;
}

# ----------------------------------------------------------------------------
#
# parse_line_with_mecab
#
# Parse a line with MeCab
#
# Split Japanese words by spaces using "MeCab" - Yet Another Part-of-Speech
# and Morphological Analyzer.
#
# $line          The line to be parsed
#
# ----------------------------------------------------------------------------
sub parse_line_with_mecab
{
    my ( $self, $line ) = @_;

    # If the line does not contain Japanese characters, do nothing
    return $line if ( $line =~ /^[\x00-\x7F]*$/ );

    # Split Japanese line into words using MeCab
    $line = $self->{nihongo_parser__}{obj_mecab}->parse( $line );

    # Remove the unnecessary white spaces
    $line =~ s/([\x00-\x1f\x21-\x7f]) (?=[\x00-\x1f\x21-\x7f])/$1/g;

    return $line;
}

# ----------------------------------------------------------------------------
#
# parse_line_with_internal_parser
#
# Parse a line with an internal perser
#
# Split characters by kind of the character
#
# $line          The line to be parsed
#
# ----------------------------------------------------------------------------
sub parse_line_with_internal_parser
{
    my ( $self, $line ) = @_;

    # If the line does not contain Japanese characters, do nothing
    return $line if ( $line =~ /^[\x00-\x7F]*$/ );

    # Split Japanese line into words by the kind of characters
    $line =~ s/\G$euc_jp_word/$1 /og;

    return $line;
}

# ----------------------------------------------------------------------------
#
# init_kakasi
#
# Open the kanwa dictionary and initialize the parameter of Kakasi.
#
# ----------------------------------------------------------------------------
sub init_kakasi
{
    # Initialize Kakasi with Wakachigaki mode(-w is passed to
    # Kakasi as argument). Both input and ouput encoding are
    # EUC-JP.

    Text::Kakasi::getopt_argv( 'kakasi', '-w', '-ieuc', '-oeuc' );
}

# ----------------------------------------------------------------------------
#
# init_mecab
#
# Create a new parser object of MeCab.
#
# ----------------------------------------------------------------------------
sub init_mecab
{
    my ( $self ) = @_;

    # Initialize MeCab (-F %M\s -U %M\s -E \n is passed to MeCab as argument).
    # Insert white spaces after words.

    $self->{nihongo_parser__}{obj_mecab}                 # PROFILE BLOCK START
        = MeCab::Tagger->new( '-F %M\s -U %M\s -E \n' ); # PROFILE BLOCK STOP
}

# ----------------------------------------------------------------------------
#
# close_kakasi
#
# Close the kanwa dictionary of Kakasi.
#
# ----------------------------------------------------------------------------
sub close_kakasi
{
    Text::Kakasi::close_kanwadict();
}

# ----------------------------------------------------------------------------
#
# close_mecab
#
# Free the parser object of MeCab.
#
# ----------------------------------------------------------------------------
sub close_mecab
{
    my ( $self ) = @_;

    $self->{nihongo_parser__}{obj_mecab} = undef;
}

# ----------------------------------------------------------------------------
#
# setup_nihongo_parser
#
# Check whether Nihongo (Japanese) parsers are available and setup subroutines.
#
# $nihongo_parser  Nihongo (Japanese) parser to use
#                  ( kakasi / mecab / internal )
#
# ----------------------------------------------------------------------------
sub setup_nihongo_parser
{
    my ( $self, $nihongo_parser ) = @_;

    # If MeCab is installed, use MeCab.
    if ( $nihongo_parser eq 'mecab' ) {
        my $has_mecab = 0;

        foreach my $prefix ( @INC ) {
            my $realfilename = "$prefix/MeCab.pm";
            if ( -f $realfilename ) {
                $has_mecab = 1;
                last;
            }
        }

        # If MeCab is not installed, try to use Text::Kakasi.
        $nihongo_parser = 'kakasi' if ( !$has_mecab );
    }

    # If Text::Kakasi is installed, use Text::Kakasi.
    if ( $nihongo_parser eq 'kakasi' ) {
        my $has_kakasi = 0;

        foreach my $prefix ( @INC ) {
            my $realfilename = "$prefix/Text/Kakasi.pm";
            if ( -f $realfilename ) {
                $has_kakasi = 1;
                last;
            }
        }

        # If Kakasi is not installed, use the internal parser.
        $nihongo_parser = 'internal' if ( !$has_kakasi );
    }

    # Setup perser's subroutines
    if ( $nihongo_parser eq 'mecab' ) {

        # Import MeCab module
        require MeCab;
        import MeCab;

        $self->{nihongo_parser__}{init}  = \&init_mecab;
        $self->{nihongo_parser__}{parse} = \&parse_line_with_mecab;
        $self->{nihongo_parser__}{close} = \&close_mecab;
    } elsif ( $nihongo_parser eq 'kakasi' ) {

        # Import Text::Kakasi module
        require Text::Kakasi;
        import Text::Kakasi;

        $self->{nihongo_parser__}{init}  = \&init_kakasi;
        $self->{nihongo_parser__}{parse} = \&parse_line_with_kakasi;
        $self->{nihongo_parser__}{close} = \&close_kakasi;
    } else {

        # Require no external modules
        $self->{nihongo_parser__}{init}  = sub { }; # Needs no initialization
        $self->{nihongo_parser__}{parse} = \&parse_line_with_internal_parser;
        $self->{nihongo_parser__}{close} = sub { };
    }

    return $nihongo_parser;
}


1;
