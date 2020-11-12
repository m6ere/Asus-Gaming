package Parser::INI;
# intended to parse various configuration file types to feed into a hash
use warnings FATAL => 'all', NONFATAL => 'syntax';  #Allows to break out at the line where the undef happned
use strict;
use Switch 'Perl6';                        #used for switch/case statements
use Text::Balanced qw (extract_quotelike );
use vars qw($VERSION);
$VERSION = 'SVN.'.(qw$Revision: 0 $)[1];
use Data::Dumper;
$Data::Dumper::SortKeys = 0;
$Data::Dumper::SortKeys = 1;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{options} = shift;
    return undef unless $self->validate();
    $self->{stats}->{comments} = 0;
    if($self->{options}->{init} == 1)
    {
        #init was requested so we need to write out the options instead of reading them
        $self->store(shift);
    } else {
        my $function = "open_". $self->{options}->{file_format};
        $self->$function();
    }
    return $self;
}

sub reload
{
    my $self = shift;
    my $function = "open_". $self->{options}->{file_format};
    $self->$function();
    return $self->get_data();
}
sub put_data
{
    my $self = shift;
    $self->{data} = shift;
}

sub get_data
{
    my $self = shift;
    return $self->{data};
}


sub store
{
    my $self = shift;
    my $data = shift || undef;
    if(defined $data)
    {
        $self->put_data($data);
    }
    my $function = "store_". $self->{options}->{file_format};
    my @output = $self->$function();
    open(my $FILE, ">", $self->{options}->{file_name});
    {
        print $FILE $_ for @output;
    }
    close ($FILE);
}

sub dump
{
    my $self = shift;
    my $function = "store_". $self->{options}->{file_format};
    return join "", ($self->$function());
}

sub open_flat_ini
{
    my $self = shift;
    my $data = $self->{data};
    %$data = ();
    open(my $FILE, "<", $self->{options}->{file_name});
    {
        while(my $line = readline($FILE))
        {
            chomp($line);
            if($line =~ /^;/)
            {
                $self->{stats}->{comments}++;
                #comment, ignore
            }elsif($line =~ /^\[/)
            {
                #section, ignore
            }else
            {
                if(my ($name, $value) = ($line=~ /^([^=]*?)\s*=\s*(.*?)$/))
                {
                    $name = uc($name) if $self->{options}->{case} == 1;
                    $name = lc($name) if $self->{options}->{case} == 2;
                    $data->{$name} = parse_line($data->{$name}, $value);
                }
            }
        }
    }
}

sub store_flat_ini
{
    my $self = shift;
    my @output;
    foreach my $key (sort keys %{$self->{data}})
    {
        if(UNIVERSAL::isa($self->{data}->{$key},"ARRAY"))
        {
            foreach my $value (@{$self->{data}->{$key}})
            {
                push @output, "$key = $value\n";
            }
        }else{
            push @output, "$key = $self->{data}->{$key}\n";
        }
    }
    return @output;
}

sub open_sectioned_ini
{
    my $self = shift;
    my $data = {};
    my $section = "";
    my @output;
    open(my $FILE, "<", $self->{options}->{file_name});
    {
        while(my $line = readline($FILE))
        {
            chomp($line);
            if($line =~ /^;/)
            {
                $self->{stats}->{comments}++;
                #comment, ignore
            }elsif($line =~ /^\[/)
            {
                ($section) = ($line =~ /^\[(.*)\]$/);
                $data->{$section} = {};
            }else
            {
                unless($section eq "")
                {
                    if(my ($name, $value) = ($line=~ /^([^=]*?)\s*=\s*(.*?)$/))
                    {
                        $name = uc($name) if $self->{options}->{case} == 1;
                        $name = lc($name) if $self->{options}->{case} == 2;
                        $data->{$section}->{$name} = parse_line($data->{$section}->{$name}, $value);
                    }
                }else{
                    #section without header!
                }
            }
        }
    }
    $self->{data} = $data;
}

sub store_sectioned_ini
{
    my $self = shift;
    my @output;
    push @output, ";Autogenrated by Parser-INI on ". localtime() ."\n";
    foreach my $key_0 (sort keys %{$self->{data}})
    {
        push @output, "[$key_0]\n";
        foreach my $key_1 (sort keys %{$self->{data}->{$key_0}})
        {
            if(UNIVERSAL::isa($self->{data}->{$key_0}->{$key_1},"ARRAY"))
            {
                foreach my $value (@{$self->{data}->{$key_0}->{$key_1}})
                {
                    push @output, "$key_1 = $value\n";
                }
            }else{
                push @output, "$key_1 = $self->{data}->{$key_0}->{$key_1}\n";
            }
        }
        push @output, "\n";
    }
    return @output;
}

sub open_pathed_ini
{
    my $self = shift;
    my $data = {};
    my $section;
    my $section_data = $data;
    open(my $FILE, "<", $self->{options}->{file_name});
    {
        while(my $line = readline($FILE))
        {
            chomp($line);
            if($line =~ /^;/)
            {
                $self->{stats}->{comments}++;
                #comment, ignore
            }elsif($line =~ /^\[/)
            {
                #sections header
                ($section) = ($line =~ /^\[(.*)\]$/);
                $section = uc($section) if $self->{options}->{case} == 1;
                $section = lc($section) if $self->{options}->{case} == 2;
                $section =~ /\/\//g;
                $section =~ s/^\///;
                $section =~ s/\/$//;
                if($section =~ /\//)
                {
                    $section_data = iterate_section($section, $data);
                }else{
                    $data->{$section} = {} unless (exists $data->{$section});
                    $section_data = $data->{$section};
                    #print "<pre>$section</pre>";
                }
            }else
            {
                #data
                my $name = "";
                my $value = "";
                if(($name, $value) = ($line=~ /^([^=]*?)\s*=\s*(.*?)$/))
                {
                    $name = uc($name) if $self->{options}->{case} == 1;
                    $name = lc($name) if $self->{options}->{case} == 2;
                    $section_data->{$name} = parse_line($section_data->{$name}, $value);
                }
            }
        }
    }
    $self->{data} = $data;
}

sub store_pathed_ini
{
    my $self = shift;
    my $data = $self->{data};
    my $flat_data;
    my @output;
    push @output, ";Autogenrated by Parser-INI on ". localtime() ."\n";
    foreach my $key (sort keys %{$data})
    {
        if(UNIVERSAL::isa($data->{$key},"HASH"))
        {
            $flat_data = iterate_store($key, $data->{$key}, $flat_data);
        }else{
            push @output, "$key = $data->{$key}\n";
        }
    }
    foreach my $section (sort keys %{$flat_data})
    {
        push @output, "[$section]\n";
        foreach my $name (sort keys %{$flat_data->{$section}})
        {
            if(UNIVERSAL::isa($flat_data->{$section}->{$name},"ARRAY"))
            {
                foreach my $value (@{$flat_data->{$section}->{$name}})
                {
                    push @output, "$name = $value\n";
                }
            }else{
                push @output, "$name = $flat_data->{$section}->{$name}\n";
            }
        }
        push @output, "\n";
    }
    return @output;
}

sub iterate_store
{
    my $path = shift;
    my $data = shift;
    my $flat_data = shift;
    foreach my $key (sort keys %{$data})
    {
        if(UNIVERSAL::isa($data->{$key},"HASH"))
        {
            $flat_data = iterate_store($path ."/". $key, $data->{$key}, $flat_data);
        }else{
            $flat_data->{$path}->{$key} = $data->{$key};
        }
    }
    return $flat_data;
}

sub parse_line
{
    my $data = shift;
    my $value = shift;
    $value = "" unless(defined $value);
    my @values;
    while( $value =~ /\".*\"/)
    {
        #looks like quoted values;
        my ($part, $value) = extract_quotelike($value);
        push @values, $part;
    }
    #anything in quotes stripped out.
    #clean down string to remove unneeded commas
    $value =~ s/\s*,\s*/,/;
    #remove empty parts
    $value =~ s/,+/,/;
    #remove starting and/or ending comma
    $value =~ s/^,|,$//;
    unless($value eq "")
    {
        if($value =~ /,/)
        {
            foreach my $val (split(/,/,$value))
            {
                push @values, $val;
            }
        }else
        {
            push @values, $value;
        }
    } else
    {
        push @values, "";
    }
    if (defined $data)
    {
        unless(ref($data) and UNIVERSAL::isa($data,"ARRAY"))
        {
            $data = [$data];
        }
        push @{$data}, @values;
    }else{
        if(@values == 1)
        {
            $data = $values[0];
        }else{
            push @{$data}, @values;
        }
    }
    return $data;
}

sub iterate_section
{
    my $section = shift;
    my $data = shift;
    if($section =~ /\//)
    {
        my ($l, $r) = split(/\//, $section, 2);
        $data->{$l} = {} unless(exists $data->{$l});
        $section = $r;
        $data = $data->{$l};
        $data = iterate_section($section, $data);
    }else{
        $data->{$section} = {} unless(exists $data->{$section});
        $data = $data->{$section};
    }
    return $data;
}

sub validate
{
    my $self = shift;
    #check for required fileds
    foreach my $option('file_format','file_name')
    {
        unless(exists $self->{options}->{$option})
        {
            $@ = "Validation of options failed for Paser::INI, missing required argument $option";
            return undef;
        }
    }
    #populate and optional fields that are technically mandatory
    $self->{options}->{init} = 0 unless(defined $self->{options}->{init});
    #check that all fields pass validation
    foreach my $key( keys %{$self->{options}})
    {
        given ( $key )
        {
            when "file_format"
            {
                if(($self->{options}->{$key} eq "flat_ini") or
                   ($self->{options}->{$key} eq "sectioned_ini") or
                   ($self->{options}->{$key} eq "pathed_ini") or
                   ($self->{options}->{$key} eq "xml")
                  )
                {
                }else{
                    $@ = "Validation of options failed for Paser::INI, unrecognized file_format $self->{options}->{file_format}";
                    return undef;
                }
            }
            when "init"
            {
                if(($self->{options}->{$key} == 1) or
                   ($self->{options}->{$key} == 0)
                  )
                {
                }else{
                    $@ = "Validation of options failed for Paser::INI, unrecognized value for init $self->{options}->{init}";
                    return undef;
                }
            }
            when "file_name"
            {
                unless (-f $self->{options}->{$key} xor $self->{options}->{init} == 1)
                {
                    $@ = "Validation of options failed for Paser::INI, the file $self->{options}->{$key} doesn't apear to exist";
                    return undef;
                }
                #no form of validation at present, consider useing a file check etc.
            }
            when "case"
            {
                given ( $self->{options}->{$key} )
                {
                    when "uppercase"
                    {
                        $self->{options}->{$key} = 1;
                    }
                    when "uc"
                    {
                        $self->{options}->{$key} = 1;
                    }
                    when "lc"
                    {
                        $self->{options}->{$key} = 2;
                    }
                    when "lowercase"
                    {
                        $self->{options}->{$key} = 2;
                    }
                    when "none"
                    {
                        $self->{options}->{$key} = 0;
                    }
                    default
                    {
                        $@ = "Validation of options failed for Paser::INI, the value $self->{options}->{$key} is not understood for the case option";
                        return undef;
                    }
                }
            }
            default
            {
                $@ = "Validation of options failed for Paser::INI, unrecognized option $key";
                return undef;
            }
        }
    }
    #defaults
    $self->{options}->{case} = 0 unless exists $self->{options}->{case};
    #indicate the options have been parsed ok
    return 1;
}

1;
