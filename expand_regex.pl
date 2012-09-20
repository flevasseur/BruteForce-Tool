#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use vars qw($opt_v $opt_expand);

my $verbose = 0;
my $expand_curly_braces = 0;
my $expand_digits = 0;
my $expand_question_mark = 0;
my $expand_set = 0;
		 
GetOptions("v|verbose" => \$verbose,
           "expand=s" => sub { set_expand_options ($_[1]); },
	   "h|?|help" => sub { usage() });

my ($rule_type,$rule_name,$rule_pat);
my @c = ();
$| = 1;
while (<>)
{
  chomp;
  next unless m<^(?:(uri|body|rawbody)\s+(\w+)\s+(/.*))>i
              || m<^(header)\s+(\w+)\s+\S+\s*(?:=~|!~)\s+(/.*)>i;
  print "\n\n$_\n" if ($verbose);
  $rule_type="$1"; $rule_name = "$2"; $rule_pat="$3";
  $_ = $rule_pat;
  print "---- expansion ----\n" if ($verbose);
  s=^/==;
  s/[smxi]$//g;
  s=/$==;
  s'\\b''g;
  s'\\\.'.'g;
  s'\\-'-'g;
  s'\\ ' 'g;
  s'\(\?:'('g;
  if ($expand_curly_braces)
  {
    # expand things like \d{1,4} into (\d|\d\d|\d\d\d|\d\d\d\d).
    s<(\\.|\[[^\]]+]|.)\{([^}]*)\}><my $regex = "$1";
				    my ($lo,$hi) = split(/\s*,\s*/,"$2");
				    $lo ||= 0; $hi ||= 0;
				    my $pat = join('',("$regex" x $lo));
				    my $m = '(' . "$pat";
				    for (($lo+1)..$hi)
				    { $pat .= "$regex"; $m .= '|' . "$pat"; }
				    $m .= ')';>gex;
  }
  if ($expand_digits)
  {
    # expand \d into (0|1...|9)
    s/\\d/[0-9]/g;
  }
  if ($expand_question_mark)
  {
    # expand ? into ((a|b...|z|0|1...|9)|)
    s/\?/([a-z0-9]|)/g;
  }
  if ($expand_set)
  {
    # convert [ABC] into equiv. (A|B|C)
    s<\[([^\]]+)]><my $chars = join('',('a'..'z','A'..'Z', '0'..'9','._-@'));
		   my $pat = "[^$1]";
		   $chars =~ s/$pat//g; # get the chars matched
		   '(' . join('|',split(//,$chars)) . ')'>gex;
  }
  @c = split('');
  my $i = 0;
  my @result = decode_pat([''], \$i);
  for (@result)
  {
    print "$_\n";
  }
  print "---------------------\n" if ($verbose);
}

sub print_list {
  for (@_) { print "$_\n"; }
}


sub decode_pat
{
  my ($so_far, $ix) = @_;
  my @this_part = ();
  my @alt_part = ('');
  my @result = ();
  my $s = '';
  for (my $i = ${$ix}; $i < @c; )
  {
    my $prevc = defined ($c[$i-1]) ? $c[$i-1] : '';
    my $ch    = $c[$i++];
    if ($ch eq '(' && $prevc ne '\\')
    {
      @alt_part = map { $_ .= $s } @alt_part;
      @alt_part = decode_pat (\@alt_part, \$i);
      $s = '';
    }
    elsif ($ch eq ')' && $prevc ne '\\')
    {
      @alt_part = map { $_ .= $s } @alt_part;
      push @this_part, @alt_part;
      ${$ix} = $i;
      @result = map {my $this_s = $_;
                        map { $this_s . $_; } @this_part } @{$so_far};
      return @result;
    }
    elsif ($ch eq '|')
    {
      @alt_part = map { $_ .= $s } @alt_part;
      push @this_part, @alt_part;
      @alt_part = ('');
      $s = '';
    }
    else
    {
      # Remove leading '\', if this is an escaped '(' or ')'
      $s =~ s/.$// if ($ch =~ /[()]/);
      $s .= $ch;
    }
  }
  @alt_part = map { $_ .= $s } @alt_part;
  push @this_part, @alt_part;
  @result = map {my $this_s = $_;
		    map { $this_s . $_; } @this_part } @{$so_far};
  return @result;
}

sub set_expand_options
{
  my $opts = $_[0];
  $expand_curly_braces ||= ($opts =~ /\{/);
  $expand_digits ||= ($opts =~ /d/);
  $expand_question_mark ||= ($opts =~ /\?/);
  $expand_set ||= ($opts =~ /\[/);
  # "expand digits" and "expand question mark" imply "expand set"
  $expand_set ||= ($expand_digits || $expand_question_mark);
}

sub usage
{
  print "usage: expand_regex [-v] [-help] [-expand=\"<expand_settings\"]\n";
  print "\twhere <expand_settings> is one of:\n";
  print "\t\td\texpand digits (ie, \\d)\n";
  print "\t\t?\texpand question mark (ie, zero ore more chars.)\n";
  print "\t\t[\texpand sets (ie, [])\n";
  print "\t\t{\texpand curly braces (ie, {n,n})\n";
  exit 1;
}
