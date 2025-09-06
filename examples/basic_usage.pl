#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;
#use FindBin;
#use lib "$FindBin::Bin/../lib";
use Vigil::QueryString;

my $qs = Vigil::QueryString->new;

#############################################################
#
#                  CREATING A QUERY STRING
#
#############################################################

print "Creating a query string with multiple levels:\n\nThis is the data structure we will use:\n";
# Original data
my $qs_data = {
    cartid => 834770,
    categories_visited => [
        'radio',
        'laptop',
        'gardening supplies',
        'tablet',
        'smartwatch',
    ],
	matrix => [
	    [1,2],
		[3,4]
	],
    custid => 123,
    settings => {
        bottom => 15,
        prefs => {
            color       => '#111',
            'text-size' => '14pt',
            'font-family' => 'verdana',
            'line-height' => 1.5,
            side        => 10,
            top         => 15,
        },
    },
};

print Dumper $qs_data;
print "\n\n";

print "Now we are saving that data to the querystring object.\n";
print "\$qs->add(\$qs_data);\n\n";
$qs->add($qs_data);

print "Now we are going to add a new key/value pair:\n";
print qq~\$qs->add('sessiondate', sprintf("%04d-%02d-%02dT%02d:%02d:%02d", ~, '(localtime)[5]+1900, (localtime)[4]+1, (localtime)[3], (localtime)[2], (localtime)[1], (localtime)[0] ) );', "\n\n";
$qs->add('sessiondate', sprintf("%04d-%02d-%02dT%02d:%02d:%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3], (localtime)[2], (localtime)[1], (localtime)[0] ) );

print "Now we are going to push another category visited:\n";
print "\$qs->append('categories_visited', 'camping');\n\n";
$qs->append('categories_visited', 'camping');

print "Now we are going to add another key/value pair to the top level hash:\n";
print q~
$qs->append(
    {
		settings => {
			volume => 2
		}
	}
);
~;

$qs->append(
    {
		settings => {
			volume => 2
		}
	}
);

print "\n\nNow we are going to add a nested array to an array:\n";
print q~$qs->append('matrix', [[5,6]]);~, "\n\n";
$qs->append('matrix', [[5,6]]);
my $matrix_ref = $qs->get('matrix');
print Dumper $matrix_ref;







print "\n\nNow we are going to add a deeper level key/value pair to the hash of hashed:\n";
print q~$qs->append(
    {
		settings => {
		    prefs => {
			    darkmode => 1
			}
		}
	}
);
~;

$qs->append(
    {
		settings => {
		    prefs => {
			    darkmode => 1
			}
		}
	}
);

print "Now we are creating the outgoing query string from this object:\n";
print '"[YOUR URL]?", $qs->create;', "\n\n";
print "[YOUR URL]?", $qs->create;

print "\n\nNow we look at what the object is holding:\n\n";
print Dumper $qs;

#############################################################
#
#                   READING A QUERY STRING
#
#############################################################

print "\n\nNow we are passing that query string to the environment variable and we will read it like it was incoming from a request-\n\n";
$ENV{QUERY_STRING} = $qs->create;
undef $qs; #Object destroyed

#As soon as you instantiate the object, it has read in
#the data from the $ENV{QUERY_STRING}. You do not need
#to explicitly "read" anything.
my $qs_incoming = Vigil::QueryString->new();

#############################################################
#
#            ACCESSING DATA FROM THE QUERY STRING
#
#			    ONE METHOD TO RULE THEM ALL!
#
#############################################################

print "Now we print some key/value pairs where values are strings (like in most query strings):\n";
print "print \$qs_incoming->get('cartid') : ", $qs_incoming->get('cartid'), "\n";
print "print \$qs_incoming->get('custid') : ", $qs_incoming->get('custid'), "\n\n";

print "Now we print some key/value pairs where values are in an array ref:\n";
my $categories_ref = $qs_incoming->get('categories_visited');
print "my \$categories_ref = \$qs_incoming->get('categories_visited');\n";
print "print \$categories_ref->[0] : ", $categories_ref->[0], "\n";
print "print \$categories_ref->[1] : ", $categories_ref->[1], "\n";
print "print \$categories_ref->[2] : ", $categories_ref->[2], "\n";
print "print \$categories_ref->[3] : ", $categories_ref->[3], "\n";
print "print \$categories_ref->[4] : ", $categories_ref->[4], "\n\n";

print "Now we print some nested arrays from key/value pairs:\n";
my $matrix_ref = $qs_incoming->get('matrix');
print "my \$matrix_ref = \$qs_incoming->get('matrix');\n";
print "print \$matrix_ref->[0][0] : ", $matrix_ref->[0][0], "\n";
print "print \$matrix_ref->[0][1] : ", $matrix_ref->[0][1], "\n";
print "print \$matrix_ref->[1][0] : ", $matrix_ref->[1][0], "\n";
print "print \$matrix_ref->[1][1] : ", $matrix_ref->[1][1], "\n";
print "print \$matrix_ref->[2][0] : ", $matrix_ref->[2][0], "\n";
print "print \$matrix_ref->[2][1] : ", $matrix_ref->[2][1], "\n\n";


print "Now we print some key/value pairs where values are in a hash ref:\n";
my $settings_ref = $qs_incoming->get('settings');
print "my \$settings_ref = \$qs_incoming->get('settings');\n";
print "print \$settings_ref->{bottom} : ", $settings_ref->{bottom}, "\n\n";

print "Now we print some key/value pairs where values are in a multi-layer hash ref:\n";
print "\$settings_ref->{prefs}{color} : ", $settings_ref->{prefs}{color}, "\n";
print "\$settings_ref->{prefs}{'text-size'} : ", $settings_ref->{prefs}{'text-size'}, "\n";
print "\$settings_ref->{prefs}{'font-family'} : ", $settings_ref->{prefs}{'font-family'}, "\n";
print "\$settings_ref->{prefs}{'line-height'} : ", $settings_ref->{prefs}{'line-height'}, "\n";
print "\$settings_ref->{prefs}{side} : ", $settings_ref->{prefs}{side}, "\n";
print "\$settings_ref->{prefs}{top} : ", $settings_ref->{prefs}{top}, "\n\n";

print "Now we extract everything into one giant hash ref:\n";
my $all_ref = $qs_incoming->get;
print "my \$all_ref = \$qs_incoming->get;\n";
print Dumper $all_ref;
print "\n\n";

#############################################################
#
#                   COPY FROM INCOMING QS
#					    TO OUTGOING QS
#
#						   REMEMBER!
#
#				 THEY ARE TWO DIFFERENT THINGS.
#
#############################################################

print "Now we are going to copy that incoming data to an outgoing query string so we can quickly reconstitute the query string:\n";
print '$qs_incoming->copy;', "\n\n";
$qs_incoming->copy;

#############################################################
#
#                  ENCRYPTING A QUERY STRING
#
#############################################################

print "Now we are going to encrypt the query string:\n\n";
#Demo encryption key - DO NOT USE THIS KEY or AAD IN YOUR OWN PROJECT!
$qs_incoming->encryption_key(encryption_key => 'd4f7a2c9b1e8f6a3c5d0b8e9f2a7c1d4b3e6f8a1c9d2b0e7f5a3c8d1b4e6f9a0', aad => 'x7Pq9zL2fB3mQ');
my $ENCRYPTED_EXAMPLE_QS = $qs_incoming->create;
print "[YOUR URL]$ENCRYPTED_EXAMPLE_QS\n\n";

print "Now we are passing that encrypted query string to the environment variable and we will read it like it was incoming from a request-\n\n";
$ENV{QUERY_STRING} = $ENCRYPTED_EXAMPLE_QS;
print "\$ENV{QUERY_STRING} : $ENV{QUERY_STRING}\n\n";

#############################################################
#
#                  DECRYPTING A QUERY STRING
#
#############################################################

my $qs_encrypted = Vigil::QueryString->new;
$qs_encrypted->encryption_key(encryption_key => 'd4f7a2c9b1e8f6a3c5d0b8e9f2a7c1d4b3e6f8a1c9d2b0e7f5a3c8d1b4e6f9a0', aad => 'x7Pq9zL2fB3mQ');
my $unencrypted_contents = $qs_encrypted->get;
print "Now we print out the contents of the decrypted query strings:\n\n";
print Dumper $unencrypted_contents;

#############################################################
#
#                          PANACHE
#
#############################################################
print "\n\n";
use MIME::Base64;
print decode_base64('RGVtbyBmaW5pc2hlZDogTXkgS3VuZy1GdSBpcyBzdHJvbmcuLi4='), "\n";
