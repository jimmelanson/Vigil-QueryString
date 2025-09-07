# NAME

Vigil::QueryString - Safe, flexible query string construction and management. Ever wish you could store an array or a hash in a
	query string? Now you can!

# SYNOPSIS

    use Vigil::QueryString;

    my $qs = Vigil::QueryString->new;

    # Add key/value pairs
    $qs->add('foo', 'bar');
    $qs->add(color => 'blue', size => 'large');
    $qs->append(color => 'red');   # Add additional value to a key
    $qs->delete('size');           # Remove a key if needed

    # Retrieve values
    my $value      = $qs->get('bar');
    my $array_ref  = $qs->get('color');        # returns arrayref if multiple values
    my @values     = @{ $qs->get('color') };   # dereference to get list
    my $hash_ref   = $qs->get;                # hashref of all pairs
    my %all_pairs  = %{ $qs->get };            # all key/value pairs

    # Create final query string
    my $url = "https://www.foo.com/program.pl?" . $qs->create;

# DESCRIPTION

Vigil::QueryString simplifies the creation and management of URL query strings. It simplifies handling arrays, hashes, and nested structures in your query strings.

\- Ensures all keys and values are properly URL-encoded.
\- Allows incremental building of key/value pairs without needing to assemble everything at once.
\- Supports retrieval of values by key, multiple keys, or the entire set of contents.
\- Generates the final query string cleanly and safely with `create`.
\- Supports arrays, nested arrays, hashes, nested hashes being placed into, and read from, querystrings.
\- It supports arbitrary nesting within practical memory and stack limits.

This module reduces boilerplate, prevents common mistakes, and provides a consistent API for handling query strings in Perl.

## GETTING DATA vs CREATING A QUERY STRING

There are two distincly different processes in this module. These are receiving a query string from an incoming request (getting) and creating a query string to be printed out to a webpage, email, etc.

The data for each of these is partitioned and only some methods work with one, while the rest work with the other.

As you read below, the methods that work _only_ with GETTING data from an incoming query string are:

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

# CLASS METHODS

- new

    Creates a new Vigil::QueryString object. The object constructor does not take any arguments.

            my $obj = Vigil::QueryString->new;

# OBJECT METHODS

- add( KEY\_VALUE\_PAIRS )

    You can add your key/value pairs in a variety of ways - choose the one that works for your style of coding and your program:

    _Outgoing query string only._

    Note that add() can get complicated as it is written to handle a wide variety of input methods. Find the one(s) you need for
    your particular purposes and focus on them.

    >     Add a single key/value pair at a time, typical of query strings:
    >
    >             $obj->add('colour', 'blue');
    >             $obj->add('length', '5.0');
    >             $obj->add('userid', 1234);
    >
    >     Add multiple key/value pairs, typical of query strings:
    >
    >     _NOTE: Pay close attention to the difference in the ways you enter these_
    >
    >         #            key       value   key       value  key      value
    >         my @data = ('colour', 'blue', 'length', '5.0', 'userid', 1234);
    >
    >         $obj->add(@data);
    >             
    >
    >     This is the only instance in which you do not enter a key name with the add method. That is when the key names are part of the list of arguments. This is also the only time you enter a full array as an argument to this method.
    >
    >     Add a list of multiple items to one key:
    >
    >         my @fruits = ('apple', 'pear', 'banana', 'kumquot');
    >
    >         $obj->add('fruit', \@fruits);
    >             
    >         $obj->add('fruit', ['apple', 'pear', 'banana', 'kumquot']);
    >             
    >         my $fruit_ref = \@fruits;
    >             
    >         $obj->add('fruit', $fruit_ref);
    >             
    >
    >     NOTE: THIS WILL NOT WORK!
    >
    >         $obj->add('fruit', @fruits);
    >             
    >
    >     Explanation as to why it won't work: If you pass an array (not an array reference), the method turns the arguments directly into a hash. Since there is a keyname, that list gets flattened and cannot be made into a set or key/value pairs.
    >
    >     Add a multi-dimensional list (nested arrays)
    >
    >         my @nested_data = ('movies', 'stories', ['soda', 'popcorn', ['jujubes', 'licorice']], 'arcades');
    >             $obj->add('entertainment', \@nested_data);
    >             
    >         my $nested_data_ref = \@nested_data;
    >             $obj->add('entertainment', $nested_data_ref);
    >             
    >         my $nested_data_ref = ['movies', 'stories', ['soda', 'popcorn', ['jujubes', 'licorice']], 'arcades'];
    >         $obj->add('entertainment', $nested_data_ref);
    >
    >     Add a hash of key/value pairs
    >
    >         my %names = (
    >           'Bobby' => 'Cooper',
    >           'Mustang' => 'Sally',
    >           'Copperhead' => 'Road'
    >         );
    >
    >         $obj->add('names', \%names);
    >             
    >         my $hash_ref = \%names;
    >         $obj->add($hash_ref);
    >             
    >         $obj->add('names', 
    >             {
    >                 'Bobby' => 'Cooper',
    >                 'Mustang' => 'Sally',
    >                 'Copperhead' => 'Road'
    >             }
    >         );
    >                     
    >
    >     NOTE: THIS WILL NOT WORK!
    >
    >         $obj->add('names', %names);
    >             
    >
    >     Add a multi-dimensional hash (HoH)
    >
    >         my %favourite_things = (
    >             people => {
    >                 singers => 'Jesse Glynne',
    >                 actors  => 'Karen Gillan',
    >                 YouTube => 'Amy Shira Teitel'
    >             },
    >             movies => {
    >                 marvel => 'Guardians of the Galaxy Vol 1 & 2',
    >                 'DC Comics' => 'Wonderwoman 1984',
    >             },
    >             Food => {
    >                 Pasta => {
    >                     Noodle => 'Spaghettini',
    >                     Sauce  => 'Bolognaise',
    >                 },
    >                 Meat => 'Meatloaf',
    >                 Breakfast => {
    >                     Protein => 'Eggs',
    >                     Side  => 'Mustard Pickles',
    >                     Carbohydrate => 'Pan Fries',
    >                 }
    >             }
    >         );
    >             
    >         $obj->add('Favourites', \%favourite_things);
    >             
    >         my $favs_hash_ref = \%favourite_things;
    >         $obj->add('Favourites', $favs_hash_ref);
    >             
    >         $obj->add('Favourites', {people => {singers => 'Jesse Glynne',actors  => 'Karen Gillan',YouTube => 'Amy Shira Teitel'},movies => {marvel => 'Guardians of the Galaxy Vol 1 & 2','DC Comics' => 'Wonderwoman 1984'},Food => {Pasta => {Noodle => 'Spaghettini', Sauce  => 'Bolognaise'}, Meat => 'Meatloaf', Breakfast => {Protein => 'Eggs', Side => 'Mustard Pickles', Carbohydrate => 'Pan Fries'}}});
    >             
    >             
    >
    >     NOTE: THIS WILL NOT WORK!
    >
    >         $obj->add('Favourites', %favourite_things);
    >             

    **OVERWRITE WARNING**

    If you add a key value pair to the object, then add that key again with a new value, the previous value gets overwritten.

        $obj->add('colour', 'blue');
        print $obj->get('colour');   #Prints: blue
            
        $obj->add('colour', 'blue');
        $obj->add('colour', 'magenta');
        print $obj->get('colour');   #Prints: magenta
            

    If you want multiple values for one key, use the `append()` method.

- append( KEY\_VALUE\_PAIRS )

    Append a string to a string - it concatenates exactly what it is given:

        $obj->add('colour' => 'green');
        #the key colour now contains => green

        $obj->append('colour' => 'red');
        #the key colour now contains => greenred

    Append a string to a list, that item gets added as a new item in the list

        $obj->add('colour' => ['fuschia', 'mauve', 'chartreuse']);
        $obj->append('colour', 'green');
        #the key colour now contains => fuschia,mauve,chartreuse,green

    Append a list to a string, that string becomes the first element in a new list

        $obj->add('pie', 'blueberry');
        $obj->append('pie', ['coconut cream', 'apple', 'lemon meringue']);
        $the key pie now contains ['blueberry', 'coconut cream', 'apple', 'lemon meringue']
            

    Append a hash ref to a key that contains a hash:

        $obj->add('people', {'singers' => 'Jesse Glynne', 'actors' => 'Karen Gillan', 'YouTube' => 'Amy Shira Teitel'});
            
        my %new_peeps = ('hockey player' => 'Bernie Parent', 'baseball player' => 'Danny Ainge', 'actors' => 'William Shatner');
        $obj->append('people', \%new_peeps);
        #people now contains: 
        {
            'singers' => 'Jesse Glynne',
            'actors' => 'William Shatner',
            'YouTube' => 'Amy Shira Teitel',
            'hockey player' => 'Bernie Parent',
            'baseball player' => 'Danny Ainge'
        }

    _Outgoing query string only._

- delete('key1', 'key2', 'key3')

    Accepts one or more keys and deletes those keys from the object.

        $obj->add('colour' => ['blue', 'red'], 'size' => 'L', 'pie' => 'blueberry');
        $obj->append('size', 'M');
        $obj->delete('colour');
        print Dumper $obj;
            #Prints out
            $VAR1 {
                'size' => ['L', 'M'],
                            'pie' => 'blueberry',
            }
                    

    _Outgoing query string only._

- exists($key)

    Returns true if the key exists. You can only check one key at a time. Also, it only works on top level keys - it will not work on nested hashes.

        return true if $obj->exists('key_name');

    _Outgoing query string only._

- get(@keys)

    Retrieves values for one, several, or all keys from the **incoming** query string. 

    _Note that this will NOT return any key/value pairs that were added or
    appended to this object in the current program instance; it only
    reflects what was received from the query string._

    There are only three types of data (strings, array references, and hash references) that are returned from
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

    **Now we `get()` keys with lists as values**

    This module allows you to create and receive key/value pairs where the value is a list.

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
            

    _INCOMING query string only._

- flatten\_returned\_list

    The default habbit of the module is to return key/value pairs with a list value, as a list. In this example,
    you can see that `sequence` and `increments` both hold lists:

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

    If you call the method `$obj->flatten_returned_list(1)`, then you will get those lists as comma separated values.

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
            

    If you apply the flatten return lists flag to hash refs, the structure does not get flattened, only the values that are lists.

    If you wish to return to list mode, then you can turn off the semaphore with `$obj->flatten_returned_list(0)`

- create

    Returns the final query string, properly URL-encoded, ready to append to a URL. The generated query string does include the query delimeter `?`.

        my $link_url = 'https://www.foo.com/nifty_program.pl?' . $obj->create;

    _Outgoing query string only._

- copy;

    Remember that `get()` deals exclusively with an incoming `$ENV{QUERY_STRING}`. Everything else deals with a query string you are building to add to a URL you are going to print to the document/screen.

    There are instances where URLs iterate through a progression. In these cases, perhaps only one value is updated and the rest remain the same.

    An example of this would be a calendar that I have in a members area of a site. Each person has the ability to save their own reminders and events to the site. When they are clicking links to move through the months, the only thing usually changing is the month number and occasionally the year number. So, instead of rebuilding the outgoing query string from scratch, you can just copy it and update it.

    Here is an incoming query string for a calendar displaying March, 2026. The user was previously on the calendar page for February, 2026 and they clicked the "Next" link:

    `$ENV{QUERY_STRING}` -> display=next&month=3&year=2026&userid=42352&reminders=on&pid=1234

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

# ENCRYPTION

In my developments, I always encrypt my query strings for all links and forms. Encrypting query strings prevents sensitive data from being exposed in URLs, protecting user information and preventing tampering.

You can encrypt and decrypt query strings on your own, using your own preferred algorithm. If you prefer, you can default to this modules algorithm for handling encryption and decryption of query strings.

The modules utilizes `ChaCha20Poly1305` through the wrapper module `Vigil::Crypt`

To use this you need two things. You need a 32 byte string of hex characters (64 characters long). If you refer to the POD for Vigil::Crypt, there is a sample script shown that will generate a cryptographically secure security key.

The other thing you need is an AAD value. AAD (Additional Authenticated Data) is extra information you provide to an authenticated encryption scheme that gets integrity-checked but not encrypted, and you create one by generating a unique string or byte sequence - often a nonce, timestamp, or user/session-specific identifier - and passing it to the encryption method alongside your plaintext.

The tricky part of an AAD is that you must have the identical AAD when decrypting as you used when encrypting. In my own projects, I generate an AAD value from user profile information that doesn't change (or doesn't change during a person's session). I can then recreate it on the decryption. I'll leave you with this to mull over and figure out in your own situation.

To use encryption on the query strings you must call the encryption\_key() method BEFORE you call `create()` or `get()`.

        $obj->encryption_key(encryption_key => $ENCRYPTION_KEY_VALUE, aad => $AAD_VALUE);

From this point on, you just need to call `get()` and/or `create()`.

Note: You can also call `$obj->aad($AAD_VALUE);` separately.

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

What the user would see looking at the sourced code of the page is something like:

    https://mydomain.com/cgi-bin/nifty_script.pl?XnL5d3w4p9Q7Gd9kZu3QF1VhYxC2sL1p9aR6uW7hQm8vT9zR3yF2xG7dJ4kN8oP0cR

## Local Installation

If your host does not allow you to install from CPAN, then you can install this module locally two ways:

- Same Directory

    In the same directory as your script, create a subdirectory called "Vigil". Then add these two lines, in this order, to your script:

            use lib '.';            # Add current directory to @INC
            use Vigil::QueryString; # Now Perl can find the module in the same dir
            
            #Then call it as normal:
            my $qs_obj = Vigil::QueryString->new;

- In a different directory

    First, create a subdirectory called "Vigil" then add it to `@INC` array through a `BEGIN{}` block in your script:

            #!/usr/bin/perl
            BEGIN {
                    push(@INC, '/path/on/server/to/Vigil');
            }
            
            use Vigil::QueryString;
            
            #Then call it as normal:
            my $qs_obj = Vigil::QueryString->new;

# AUTHOR

Jim Melanson (jmelanson1965@gmail.com).

Created: October, 2019.

Last Update: August 2025.

License: Use it as you will, and don't pretend you wrote it - be a mensch.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
