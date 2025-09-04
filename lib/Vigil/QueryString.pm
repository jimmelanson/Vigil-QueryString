package Vigil::QueryString;

use strict;
use warnings;
use URI::Escape;

our $VERSION = 1.0.0;

sub new {
    my ($class) = @_;
    bless { 
	    _encryption_key => undef, 
		_aad        => undef,
		_extracted  => 0,
		_contents   => {},
		_new_qs     => {},
		_flatten_returned_lists => 0,
		_last_error => '' }, $class;
}

sub encryption_key {
	my($self, %args) = @_;
	%args = map { lc($_) => $args{$_} } keys %args;
    unless(defined $args{encryption_key} && length($args{encryption_key}) == 64) {
		die "Vigil::QueryString: Invalid encryption key length (must be 64 hex chars)";
        return;
    }
	$self->{_encryption_key} = $args{encryption_key};
	$self->{_aad} = $args{aad};
    return 1;
}

sub encryption_aad {
	my ($self, $aad) = @_;
	if(defined $aad && length($aad) > 0) {
		$self->{_aad} = $aad;
	}
	return 1;
}

sub flatten_returned_list { $_[0]->{_flatten_returned_lists} = $_[1] ? 1 : 0; }

sub get {
    my ($self, @keys) = @_;
	
    # Ensure we have extracted the incoming QS
    $self->_extract unless $self->{_extracted};
	
    my $data = $self->{_contents};


    # No args: return full hashref (with arrayrefs for multi-value keys)
    if (!@keys) {
        my %result;
        foreach my $key (keys %$data) {
            if ($data->{$key} =~ /,/) {
                my @vals = split /,/, $data->{$key};
                $result{$key} = \@vals;
            } else {
                $result{$key} = $data->{$key};
            }
        }
        return \%result;
    }

    # Single key
    if (@keys == 1) {
        my $key = $keys[0];
        return undef unless exists $data->{$key};
        if ($data->{$key} =~ /,/) {
            my @vals = split /,/, $data->{$key};
            #return \@vals;
			return $self->{_flatten_returned_lists} ? join(',', @vals) : \@vals;
        }
        return $data->{$key};
    }

    # Multiple keys
    my @result;
    foreach my $key (@keys) {
        if (exists $data->{$key}) {
            if ($data->{$key} =~ /,/) {
                my @vals = split /,/, $data->{$key};
                push @result, \@vals;
            } else {
                push @result, $data->{$key};
            }
        } else {
            push @result, undef;
        }
    }
    return \@result;
}



sub add {
    my ($self, @args) = @_;

    # Flatten if a single ref is passed
    if (@args == 1) {
        if (ref $args[0] eq 'ARRAY')  { @args = @{$args[0]}; }
        elsif (ref $args[0] eq 'HASH') { @args = %{$args[0]}; }
    }

    # Convert list to hash to normalize key/value pairs
    my %pairs = @args;

    # Replace existing values with new arrayrefs
    for my $key (keys %pairs) {
        my $val = $pairs{$key};

        if (ref($val) eq 'ARRAY') {
            # Flatten nested arrays
            $val = [ map { ref($_) eq 'ARRAY' ? @$_ : $_ } @$val ];
        }
        elsif (ref($val) eq 'HASH') {
            # Flatten hash into alternating key,value pairs
            $val = [ map { ($_ => $val->{$_}) } sort keys %$val ];
        }
        else {
            $val = [$val];  # wrap scalar
        }

        $self->{_new_qs}{$key} = $val;
    }
}

sub append {
    my ($self, @args) = @_;

    # Flatten if a single ref is passed
    if (@args == 1) {
        if (ref $args[0] eq 'ARRAY')  { @args = @{$args[0]}; }
        elsif (ref $args[0] eq 'HASH') { @args = %{$args[0]}; }
    }

    # Convert list to hash to normalize key/value pairs
    my %pairs = @args;

    for my $key (keys %pairs) {
        my $val = $pairs{$key};

        if (ref($val) eq 'ARRAY') {
            $val = [ map { ref($_) eq 'ARRAY' ? @$_ : $_ } @$val ];
        }
        elsif (ref($val) eq 'HASH') {
            $val = [ map { ($_ => $val->{$_}) } sort keys %$val ];
        }
        else {
            $val = [$val];
        }

        # Push values into the existing arrayref
        push @{ $self->{_new_qs}{$key} ||= [] }, @$val;
    }
}

sub copy {
    my ($self) = @_;

    # Ensure we have extracted the incoming QS
    $self->_extract unless $self->{_extracted};

    # Copy all extracted key/value pairs into _new_qs
    for my $key (keys %{ $self->{_contents} }) {
        my $val = $self->{_contents}{$key};
        # Duplicate arrayrefs to avoid modifying the original
        $self->{_new_qs}{$key} = ref $val eq 'ARRAY' ? [ @$val ] : $val;
    }

    return 1;  # success
}

sub reset {
    my ($self) = @_;
    $self->{_extracted} = 0;
    $self->{_contents} = {};
	$self->{_flatten_returned_lists} = 0;
	$self->{_new_qs} = {};
    #$self->_extract;
}

sub delete {
	my ($self, @args) = @_;
	delete $self->{_new_qs}{ $_ } foreach @args;
}

sub exists {
	my ($self, $key) = @_;
	return exists $self->{_new_qs}{$key};
}

sub create {
    my $self = shift;
	$self->add(@_) if @_;
    my $new_qs;
    # Build from $self->{_new_qs}
    if ($self->{_new_qs} && keys %{ $self->{_new_qs} }) {
        for my $key (sort keys %{ $self->{_new_qs} }) {
            $new_qs .= '&' if $new_qs;

            my $value = defined $self->{_new_qs}{$key} ? $self->{_new_qs}{$key} : '';

            # Flatten arrayrefs
            if (ref($value) eq 'ARRAY') {
                $value = join(',', @$value);

            # Flatten hashrefs into key=value,key=value form
            } elsif (ref($value) eq 'HASH') {
                $value = join(',', map { "$_=$value->{$_}" } keys %$value);
            }

            $value = $self->_url_encode($value) if $value;
            $new_qs .= $key . '=' . $value;
        }
    }
	return unless $new_qs;
    if ($self->{_encryption_key}) {
        use Vigil::Crypt;
        my $crypt = Vigil::Crypt->new($self->{_encryption_key});
        $new_qs = $crypt->encrypt($new_qs, $self->{_aad});
    }
	return '?' . $new_qs;
}

sub create_reset {
    my ($self, @args) = @_;
    $self->reset;
    return $self->create(@args);
}

sub _extract {
	my $self = shift;
	return if $self->{_extracted};
	$self->{_extracted} = 1;
	my %temp;
	if( $ENV{QUERY_STRING} ne "" ){
		my $query_string = $ENV{QUERY_STRING};
		$query_string =~ s/^\?//;
		if($self->{_encryption_key}) {
			use Vigil::Crypt;
			my $crypt = Vigil::Crypt->new($self->{_encryption_key});
			$query_string = $crypt->decrypt($query_string, $self->{_aad});
		}
		$query_string = $self->_url_decode($query_string);
		my @temp_qs_pairs = split(/\&/, $query_string);
		foreach my $temp_qs_pair (@temp_qs_pairs) {
			my($temp_qs_key, $temp_qs_value) = split(/\=/, $temp_qs_pair);
			$temp_qs_key = $self->_sanitize($temp_qs_key);
			$temp_qs_value = $self->_sanitize($temp_qs_value);
			
			# Convert empty string to undef, but preserve "0"
            $temp_qs_value = undef if defined($temp_qs_value) && $temp_qs_value eq '';

            #First at the gate
			$temp{$temp_qs_key} = $temp_qs_value unless exists $temp{$temp_qs_key};

		}
	}
	$self->{_contents} = \%temp;
}

sub _url_encode {
	my ($self, $string) = @_;
	return unless defined $string && $string;
    $string =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord($1))/ge;
    return $string;
}

sub _url_decode {
	my ($self, $string) = @_;
	return unless defined $string && $string;
	$string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
	return $string;
}

sub _sanitize {
	my ($self, $value) = @_;
	return unless defined($value) && ($value ne '' || $value == 0);
    $value =~ s/\%0A//ig; # LF
    $value =~ s/\%0D//ig; # CR
	$value =~ s/<.+?>//gs;
	$value =~ s/<!--(.|\n)*-->//gsx;
	$value =~ s/\\//g;
	$value =~ s/\.\.([\/\:]|$)//g;
	$value =~ s/\.([\/\:]|$)//g;
	$value =~ s!\.\./!!g;
	$value =~ s/^\.$//g;
	#Encoded HTML tags
	$value =~ s/(\%3C).+?(\%3E)//ig;
	#Double encoded HTML tags
	$value =~ s/(\%253C).+?(\%253E)//ig;
	#Basic HTML entities
	$value =~ s/\&quot\;//ig;
	$value =~ s/\&gt\;//ig;
	$value =~ s/\&lt\;//ig;
	$value =~ s/\%2e//ig; # .
	$value =~ s/\%2f//ig; # /
	$value =~ s/\%5c//ig; # \
	$value =~ s/\%252E//ig; # .
	$value =~ s/\%255C//ig; # /
	$value =~ s/\%c0%af//ig; # /
	$value =~ s/\%c1%9c//ig; # \
	#Other things
	$value =~ s/\%00//ig;
	$value =~ s/\x00//ig;
	$value =~ s/\~//g;

	return $value;
}

1;

__END__

=head1 NAME

Vigil::QueryString - Safe, flexible query string construction and management

=head1 SYNOPSIS

    use Vigil::QueryString;

    my $qs = Vigil::QueryString->new;

    # Add key/value pairs
    $qs->add(color => 'blue', size => 'large');
    $qs->append(color => 'red');   # Add additional value to a key
    $qs->delete('size');           # Remove a key if needed

    # Retrieve values
    my $color      = $qs->get('color');        # returns arrayref if multiple values
    my @values     = @{ $qs->get('color') };   # dereference to get list
    my %all_pairs  = $qs->get;                 # all key/value pairs
    my $all_ref    = $qs->get;                 # hashref of all pairs

    # Create final query string
    my $url = "https://www.foo.com/program.pl?" . $qs->create;

=head1 DESCRIPTION

Vigil::QueryString simplifies the creation and management of URL query strings.  

- Ensures all keys and values are properly URL-encoded.
- Allows incremental building of key/value pairs without needing to assemble everything at once.
- Supports retrieval of values by key, multiple keys, or the entire set of contents.
- Generates the final query string cleanly and safely with C<create>.

This module reduces boilerplate, prevents common mistakes, and provides a consistent API for handling query strings in Perl.


=head2 GETTING DATA vs CREATING A QUERY STRING

There are two distincly different processes in this module. These are receiving a query string from an incoming request (getting) and creating a query string to be sent out to a webpage/etc.

The data for each of these is partitioned and only some methods work with one, while the rest work with the other.

As you read below, the methods that work I<only> with GETTING data from an incoming query string are:

	$obj->get
	$obj->flatten_returned_list
	$obj->copy
	
The methods that only work with CREATING a new outgoing query string are:

	$obj->add
	$obj->append
	$obj->delete
	$obj->exists
	$obj->create

The non-constructor methods that work with both getting and creating are:

	$obj->encryption_key
	$obj->copy
	$obj->reset   #Use carefully



=head1 CLASS METHODS

=over 4

=item new

Creates a new Vigil::QueryString object. The object constructor does not take any arguments.

	my $obj = Vigil::QueryString->new;

=back

=head1 OBJECT METHODS

=over 4

=item add( KEY_VALUE_PAIRS )

You can add your key/value pairs in a variety of ways - choose the one that works for your style of coding and your program:

I<Outgoing query string only.>

=over 4

(key => value)      Standard hash syntax; works as a single key/value pair

(key, value)        Flat list; equivalent to the previous one but not using =>

(@key_value_pairs)  Flat list of multiple keys and values

(%keyvaluepairs)    Hash variable; converted internally to key/value pairs

($arrayref)         Array reference; automatically dereferenced ("flattened") to a list of key/value pairs

(\@array)           Array reference; automatically dereferenced to a list of key/value pairs

($hashref)          Hash reference; automatically dereferenced to a list of key/value pairs

(\%hash)            Hash reference; automatically dereferenced to a list of key/value pairs

([a,b,c,d])         Arrayref of key/value pairs; automatically flattened

({a,b,c,d})         Hashref of key/value pairs; automatically flattened

=back

Here are examples of each:

	$obj->add('colour' => 'blue');
	$obj->add('colour' => 'blue', 'length' => '5.0', 'userid' => 1234);
	$obj->add('colour', 'blue', 'length', '5.0', 'userid', 1234);
	
	#Add an array
	my @data = ('colour', 'blue', 'length', '5.0', 'userid', 1234);
	$obj->add(@data);
	
	#Add an array ref
	$obj->add(\@data);
	$obj->add(['colour', 'blue', 'length', '5.0', 'userid', 1234]);
	my $arrayref = \@data;
	$obj->add($arrayref);
		
	#Add a hash
	my %data = ('colour' => 'blue', 'length' => '5.0', 'userid' => 1234);
	$obj->add(%data);
	
	#Add a hash ref
	$obj->add(\%data);
	my $hashref = \%data;
	$obj->add($hashref);
	$obj->add({'colour' => 'blue', 'length' => '5.0', 'userid' => 1234});
	
Here is an example of adding a key value pair where one value is a list:

	$obj->add(
		color    => ['blue', 'red'],  # value is an arrayref
		size     => 'large',
		userid   => 1234
	);
	
This will also work:

	my @colours = ('blue', 'red');
	$obj->add(
		color    => \@colours,  # value is an array ref
		size     => 'large',
		userid   => 1234
	);
	
The resulting query string would concatenate that list with commas like this:

    "colour=blue,red&size=large&userid=1234"
	
This will B<NOT WORK>:

	my @colours = ('blue', 'red');
	$obj->add(
		color    => @colours,  #value is an array: BAD
		size     => 'large',
		userid   => 1234
	);
	

B<OVERWRITE WARNING>

If you add a key value pair to the object, then add that key again with a new value, the previous value gets overwritten.

	$obj->add('colour', 'blue');
	print $obj->get('colour');   #Prints: blue
	
	$obj->add('colour', 'blue');
	$obj->add('colour', 'magenta');
	print $obj->get('colour');   #Prints: magenta
	
If you want multiple values for one key, use the C<append()> method.


=item append( KEY_VALUE_PAIRS )

Appends additional values to keys, creating a list if the key already exists.

	$obj->add(colour => 'green');
	#the key colour now contains => green

	$obj->append(colour => 'red');
	#the key colour now contains => green,red

	$obj->append(color => ['fuschia', 'mauve', 'chartreuse']);
	#the key colour now contains => green,red,fuschia,mauve,chartreuse

I<Outgoing query string only.>

=item delete('key1', 'key2', 'key3')

Accepts one or more keys and deletes those keys from the object.

    $obj->add('colour' => ['blue', 'red'], 'size' => 'L');
    $obj->append('size', 'M');
    $obj->delete('colour');
    print Dumper $obj;
        #Prints out
        $VAR1 {
            'size' => ['L', 'M'],
        }
		
I<Outgoing query string only.>

=item exists($key)

Returns true if the key exists. You can only check one key at a time.

    return true if $obj->exists('key_name');

I<Outgoing query string only.>

=item get(@keys)

Retrieves values for one, several, or all keys from the incoming query string. 

I<Note that this will NOT return any key/value pairs that were added or
appended to this object in the current program instance; it only
reflects what was received from the query string.>

There are only three types of data (strings, lists, and references) that are returned from
this method, but they are returned in very useful ways.The most common access will be for
a single key to return a single value:

URL?colour=blue&foo=bar&baz=qux

    my $colour = $obj->get('colour');
	

If you want to get more than one value at a time, then the results will be returned as an array ref:

URL?colour=blue&size=X-Large&foo=bar&baz=qux

    my $vals = $obj->get('colour','size');
	
    print $vals->[0];     #Prints: blue
	
    print $vals->[1];     #Prints: X-large


If you choose to access ALL of the querystrings key/value pairs at once, then it will be returned to you as a hash ref.

URL?colour=blue&size=X-Large&foo=bar&baz=qux

    my $hash_ref = $obj->get;  #In scalar context
	
    print $hash_ref->{colour}; #Prints: blue
	
    print $hash_ref->{size};   #Prints: X-large
	
    print $hash_ref->{foo};    #Prints: bar
	
    print $hash_ref->{baz};    #Prints: qux


B<Now we C<get()> keys with lists as values>

This module allows you to create and receive key/value pairs where the value is a list. In a query string this has to be
represented as a CSV string, but the object will convert it to a list for you.

URL?colour=blue,green,red&size=X-Large&foo=bar&baz=qux

    my $colour = $obj->get('colour');
	
    print $colour;                #Prints something like: ARRAY(0x55a1c3f8e3c0)
	
    print join(', ', @$colour);   #Prints: blue, green, red

    print $colour->[0];           #Prints: blue
	
    print $colour->[1];           #Prints: green
	
    print $colour->[2];           #Prints: red


Selecting multiple keys with one as a list

    my $multiples = $obj->get('colour', 'size', 'foo');

    print join(', ', @{$multiples->[0]}); #Prints: blue, green, red

    print $multiples->[0][0];         #Prints: blue
	
    print $multiples->[0][1];         #Prints: green
	
    print $multiples->[0][2];         #Prints: red

    print $multiples->[1];            #Prints: X-large
    
    print $multiples->[2];            #Prints: bar
	
Selecting the whole thing, some keys with lists:

    my $hash_ref = $obj->get;
	
    print $hash_ref->{colour};        #Prints something like: ARRAY(0x55a1c3f8e3c0)
	
    print $hash_ref->{colour}[0]; #Prints: blue
	
    print $hash_ref->{colour}[1]; #Prints: green
	
    print $hash_ref->{colour}[2]; #Prints: red
	
    print $hash_ref->{size};      #Prints: X-Large
	
    print $hash_ref->{foo};       #Prints: foo
	
    print $hash_ref->{baz};       #Prints: qux
	
I<INCOMING query string only.>

=item flatten_returned_list

The default habbit of the module is to return key/value pairs with a list value, as a list. In this example,
you can see that C<sequence> and C<increments> both hold lists:

    $VAR1 = {
        'codedoc' => '19-456-7',
        'sequence' => [
                          'a23',
                          '407',
                          'x32',
                          '514'
                        ],
        'ip' => '26.182.232.4',
        'app' => '32x4',
        'port' => '683',
        'repeats' => '11525',
        'id' => '897uhjjpa05',
        'nonce' => '38276591',
        'increments' => [
                            '5',
                            '9',
                            '12',
                            '14'
                          ],
        'prev' => 'no'
    };

If you call the method C<$obj-E<gt>flatten_returned_list(1)>, then you will get those lists as comma separated values.

    $VAR1 = {
          'app' => '32x4',
          'repeats' => '11525',
          'sequence' => 'a23,407,x32,514',
          'port' => '683',
          'nonce' => '38276591',
          'increments' => '5,9,12,14',
          'ip' => '26.182.232.4',
          'prev' => 'no',
          'codedoc' => '19-456-7',
          'id' => '897uhjjpa05'
    };

If you wish to return to list mode, then you can turn off the semaphore with C<$obj-E<gt>flatten_returned_list(0)>


In the section on the C<get> method, you saw these:

URL?colour=blue,green,red&size=X-Large&foo=bar&baz=qux

    my $colour = $obj->get('colour');
	
    print $colour;                #Prints something like: ARRAY(0x55a1c3f8e3c0)
	
    print join(', ', @$colour);   #Prints: blue, green, red

    print $colour->[0];           #Prints: blue
	
    print $colour->[1];           #Prints: green
	
    print $colour->[2];           #Prints: red


Selecting multiple keys with one as a list

    my $multiples = $obj->get('colour', 'size', 'foo');

    print join(', ', @{$multiples->[0]}); #Prints: blue, green, red

    print $multiples->[0][0];         #Prints: blue
	
    print $multiples->[0][1];         #Prints: green
	
    print $multiples->[0][2];         #Prints: red

    print $multiples->[1];            #Prints: X-large
    
    print $multiples->[2];            #Prints: bar
	
With the C<$obj-E<gt>flatten_returned_list(1)> turned on, the results would be:

URL?colour=blue,green,red&size=X-Large&foo=bar&baz=qux

    my $colour = $obj->get('colour');
	
    print $colour;                #Prints: blue, green, red
	
    print join(', ', @$colour);   #Use of uninitialized value in array dereference

    print $colour->[0];           #Prints: b
	
Selecting multiple keys with one as a list

    my $multiples = $obj->get('colour', 'size', 'foo');

    print join(', ', @{$multiples->[0]}); #Use of uninitialized value in array dereference

    print $multiples->[0][0];         #Prints: b
	
    print $multiples->[0];            #Prints: blue, green, red
	
    print $multiples->[1];            #Prints: X-large
    
    print $multiples->[2];            #Prints: bar

B<WARNING: The C<$obj-E<gt>flatten_returned_list(1)> method has NO effect on the arrayref returned when you call C<$obj-E<gt>get> with no arguments.>

=item create

Returns the final query string, properly URL-encoded, ready to append to a URL. The generated query string does not include the query delimeter C<?>.

    my $link_url = 'https://www.foo.com/nifty_program.pl?' . $obj->create;

I<Outgoing query string only.>


=item copy;

Remember that C<get()> deals exclusively with an incoming C<$ENV{QUERY_STRING}>. Everything else deals with a query string you are building to add to a URL you are going to print to the document/screen.

There are instances where URLs iterate through a progression. In these cases, perhaps only one value is updated and the rest remain the same.

An example of this would be a calendar that I have in a members area of a site. Each person has the ability to save their own reminders and events to the site. When they are clicking links to move through the months, the only thing usually changing is the month number and occasionally the year number. So, instead of rebuilding the outgoing query string from scratch, you can just copy it and update it.

Here is an incoming query string for a calendar displaying March, 2026. The user was previously on the calendar page for February, 2026 and they clicked the "Next" link:

C<$ENV{QUERY_STRING}> -> display=next&month=3&year=2026&userid=42352&reminders=on&pid=1234

Now I want to print out the link for the previous month and the next month on the page that is being displayed:

    #Instantiate the object
    my $querystring = Vigil::QueryString->new;
	
    #Copy the incoming query string to the object as an outgoing query string
    $querystring->copy;

    #Preserve the year and month of the current page displayed.
    my ($target_year, $target_month) = $querystring->get('year', 'month');

    #Now we are creating the link for the next month (April, 2026).
    my ($new_month, $new_year) = validate_ym($target_year, $target_month, 1);
	
    #Now we overwrite the year and month by using C<add()>
    $querystring->add('year', $new_year, 'month', $new_month);
	
    #Now we concatenate the URL with the new query string values
    my $new_link_NEXT_month = "URL?" . $querystring->create;
    #This will output:  URL?display=next&month=4&year=2026&userid=42352&reminders=on&pid=1234

    #Now we are creating the link for the previous month (February, 2026).
    my ($new_month, $new_year) = validate_ym($target_year, $target_month, -1);
	
    #Now we overwrite the year and month AGAIN by using C<add()>
    $querystring->add('year', $new_year, 'month', $new_month, 'display', 'previous');
	
    #Now we concatenate the URL with the new query string values
    my $new_link_PREVIOUS_month = "URL?" . $querystring->create;
    #This will output:  URL?display=previous&month=2&year=2026&userid=42352&reminders=on&pid=1234

=back

=head1 ENCRYPTION

In my developments, I always encrypt my query strings for all links and forms. Encrypting query strings prevents sensitive data from being exposed in URLs, protecting user information and preventing tampering.

You can encrypt and decrypt query strings on your own, using your own preferred algorithm. If you prefer, you can default to this modules algorithm for handling encryption and decryption of query strings.

The modules utilizes C<ChaCha20Poly1305> through the wrapper module C<Vigil::Crypt>

To use this you need two things. You need a 32 byte string of hex characters (64 characters long). If you refer to the POD for Vigil::Crypt, there is a sample script shown that will generate a cryptographically secure security key.

The other thing you need is an AAD value. AAD (Additional Authenticated Data) is extra information you provide to an authenticated encryption scheme that gets integrity-checked but not encrypted, and you create one by generating a unique string or byte sequence - often a nonce, timestamp, or user/session-specific identifier - and passing it to the encryption method alongside your plaintext.

The tricky part of an AAD is that you must have the identical AAD when decrypting as you used when encrypting. In my own projects, I generate an AAD value from user profile information that doesn't change (or doesn't change during a person's session). I can then recreate it on the decryption. I'll leave you with this to mull over and figure out in your own situation.

To use encryption on the query strings you must call the encryption_key() method BEFORE you call C<create()> or C<get()>.

	$obj->encryption_key(encryption_key => $ENCRYPTION_KEY_VALUE, aad => $AAD_VALUE);

From this point on, you just need to call C<get()> and/or C<create()>.

Here is a more verbose example:


    /config.lib

    our constant ENCRYPTION_KEY => 'f3a9c1d5e7b82f0a4c1d2e3f4b5a6978f0e1d2c3b4a59687f0e1d2c3b4a59687';

    /nifty_script.pl
	
    ...blah...
		
    use Vigil::QueryString;
    my $qs = Vigil::QueryString->new;
    $qs->encryption_key(encryption_key => ENCRYPTION_KEY, aad => 'user' . $userid);

    my $userid = get_userid_from_somewhere();

    #Getting key value pairs from an encrypted query string
    my %kv_pairs = $qs->get;
	
	#Creating an encrypted query string
    $qs->add('userid', $userid);
    $qs->add('next', 'add_tasks');
	
    my $script_url = "https://$ENV{'SERVER_NAME'}$ENV{'SCRIPT_NAME'}" . '?' . $qs->create;

What the user would see looking at the sourced code of the page is:

    https://mydomain.com/cgi-bin/nifty_script.pl?XnL5d3w4p9Q7Gd9kZu3QF1VhYxC2sL1p9aR6uW7hQm8vT9zR3yF2xG7dJ4kN8oP0cR


=head2 Local Installation

If your host does not allow you to install from CPAN, then you can install this module locally two ways:

=over 4

=item * Same Directory

In the same directory as your script, create a subdirectory called "Vigil". Then add these two lines, in this order, to your script:

	use lib '.';            # Add current directory to @INC
	use Vigil::QueryString; # Now Perl can find the module in the same dir
	
	#Then call it as normal:
	my $qs_obj = Vigil::QueryString->new;

=item * In a different directory

First, create a subdirectory called "Vigil" then add it to C<@INC> array through a C<BEGIN{}> block in your script:

	#!/usr/bin/perl
	BEGIN {
		push(@INC, '/path/on/server/to/Vigil');
	}
	
	use Vigil::QueryString;
	
	#Then call it as normal:
	my $qs_obj = Vigil::QueryString->new;

=back

=head1 AUTHOR

Jim Melanson (jmelanson1965@gmail.com).

Created: October, 2019.

Last Update: August 2025.

License: Use it as you will, and don't pretend you wrote it - be a mensch.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut






