package AO::Core::Utils;
require 5.008;
require Exporter;
use warnings;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION %EXPORT_TAGS);
use File::Glob qw ( bsd_glob );
use File::Spec qw ( catdir );

$VERSION = 'SVN.'.(qw$Revision: 325 $)[1];
@ISA = qw( Exporter );
@EXPORT = ( qw( load_modules) );
@EXPORT_OK = ();

sub export_tag($@) {
	my ($tag,@names) = @_;
	if (defined($EXPORT_TAGS{$tag}))
	{
		my $ret=$EXPORT_TAGS{$tag};
		@names=(@names,@$ret);
	}
	$EXPORT_TAGS{$tag}=\@names;
}
sub load_modules($;$$);
sub do_load_modules($$$;$);

sub load_modules($;$$)
{
	my @root;
	my $module_base;
	my $recurse = 0;
	my $parser_modules = {};
	if(@_ == 3)
	{
		push @root, shift;
		$module_base = shift;
		$recurse = shift;
	}elsif(@_ == 2)
	{
		push @root, shift;
		$module_base = shift;
		if($module_base eq "1")
		{
			$module_base = shift @root;
			@root = @INC;
			$recurse = 1;
		}
	}
	else
	{
		@root = @INC;
		$module_base = shift;
	}
	foreach my $root (@root)
	{
		do_load_modules($root, $module_base, $parser_modules, $recurse);
	}
    return keys %$parser_modules;
}

sub do_load_modules($$$;$)
{
    my $root = shift;
	my $module_base = shift;
	my $parser_modules = shift;
	my $recurse = shift || 0;
	#warn "i am useing a root of $root and searching for modules inside $module_base";
	my $dir = File::Spec->catdir($root,split(/::/,$module_base));
	$root = File::Spec->catdir(File::Spec->splitdir($root));
	#$dir = File::Spec->catdir(File::Spec->splitdir($dir));
	for my $file (bsd_glob(File::Spec->catfile($dir,"*"))) {
		if (-d $file and $recurse == 1) {
			do_load_modules($root,$module_base."::".basename($file),$parser_modules, $recurse);
		} elsif ($file=~/\.pm\z/i) {
			my $module = $file;
			$module=~s{\A\Q$root\E/?}{};
			$module = join("::",File::Spec->splitdir($module));
			$module=~s{\.\w+\z}{};
			$module=~s/^:://;			# Win32 Active Perl Fix
			#warn "I am about to attempt to use the module $module";
			#unless($module=~/^\w:::/)	# Win32 Active Perl Fix
			#{
				if (eval qq{ use $module (); 1 }) {
					$parser_modules->{$module} = 1;
				} else {
				}
			#}
		}
	}
	#warn "i managed to load @parser_modules modules consisting of ". join(" ",@parser_modules);
    return $parser_modules;
}
#------------------------------- END OF FUNCTIONS -------------------

# Auto EXPORT_OK
foreach my $et (keys %EXPORT_TAGS)
{
	Exporter::export_ok_tags($et);
}

1;