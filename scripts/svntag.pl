#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use File::Copy;
use File::Basename;

sub Usage
{
  print "Usage: $::myname -b branch_name\n\t-h for full help\n";
  exit ;
}

sub Help 
{
  print "$0 -t tag_name\n";
  print "This script will do the grunt work of tagging netforts, fms, and all the defined\n".
        "external modules.  You must have a local workspace containing the basis for your\n".
        "branch, and run this from the top level of your workspace.  Your branch name cannot\n".
        "contain special characters.  Please limit yourself to alphanumeric, underscores, and\n".
        "periods.\n";
  exit ;
}

sub CheckName
{
  my $tag=shift;
  if ($tag !~ /^[\w\.]+$/) {
    print "Tag name of ($tag) contains illegal characters.\n";
    print "Please limit yourself to alphanumeric, underscores, and periods.\n";
    exit;
  }
}

sub CheckSpace
{
  my $exref=shift;
  foreach (@{ $exref },'fms','.svn') {
    unless (-d $_) {
      print "You don't seem to have a complete workspace in this directory.\n".
            "$_ is missing, and perhaps more.\n";
      exit;
    }
  }
}

sub GetExternals
{
  my @ex;

  open(EX,"./svn-externals") || die "Couldn't open svn-externals file: $!\n";
  while(<EX>) {
    next if(/^#/ || /^$/);
    /^(\S+)\s+/;
    push @ex, $1;
  }
  close(EX);
  return @ex;
}

sub CheckTag
{
  my $tag = shift;

  system("$::svn list svn+ssh://$::host/$::path/netforts/tags/$tag > /dev/null 2>&1");
  my $exit_code= $? >> 8;
  unless ($exit_code) {
    die "Sorry, that tag name already exists, please choose another.\n";
  }
}

sub TagExternals
{
  my $tag=shift;
  my $exref=shift;
  my ($mod,%ex,@new);

  foreach $mod (@{$exref}) {
    chdir($mod);
    print "Tagging $mod ... ";
    print "Find svn entries referring to 'netforts'\n";
    my $nentries_error = `/usr/bin/find -name "entries" | /usr/bin/xargs /bin/egrep "svn\\+ssh://babylon.eng.netforts.com" | /usr/bin/wc -l`;
    chomp($nentries_error);
    if ($nentries_error > 0) {
      print ("Found $nentries_error files referring to babylon.eng.netforts.com\n");
      system("/usr/bin/find -name \"entries\" | /usr/bin/xargs /bin/egrep \"svn\\+ssh://babylon.eng.netforts.com\" | /bin/sed -e \"s/^/  /\"");
      print ("Replacing 'babylon.eng.netforts.com' with 'babylon.eng.fireeye.com'\n");
      system("/bin/sed -i.bak -e 's/netforts/fireeye/g' `/usr/bin/find -name \"entries\" | /usr/bin/xargs /bin/egrep \"svn\\+ssh://babylon.eng.netforts.com\" | /bin/awk -F: '{print \$1}'`");
      print ("Done $?\n");
    } else {
      print ("Found $nentries_error files referring to babylon.eng.netforts.com\n");
    }

    print "Tagging $mod ... \n";
    print("  $::svn copy -m \"svntag.pl: Creating tag $tag\" . svn+ssh://$::host/$::path/$mod/tags/$tag\n");
    system("$::svn copy -m \"svntag.pl: Creating tag $tag\" . svn+ssh://$::host/$::path/$mod/tags/$tag");
    my $exit_code= $? >> 8;
    if($exit_code) {
      die "There was an error when tagging $mod: $!\n.";
    } else {
      print "Done\n";
    }
    chdir("..");
    $ex{$mod}="svn+ssh://$::host/$::path/$mod/$tag";
  }
  print "Updating svn-externals file ... ";
  open(EX,'./svn-externals') || die "Couldn't open svn-externals for read: $!\n";
  while(<EX>) {
    if ($_ =~ /^(\S+)\s+svn\+ssh:/ && defined($ex{$1})) {
      push @new,"$1\tsvn+ssh://$::host/$::path/$1/tags/$tag\n";
    } else {
      push @new,$_;
    }
  }
  close(EX);
  open(NEX,'>./svn-externals.new') || die "Couldn't open svn-externals for write: $!\n";
  print NEX @new;
  close(NEX);
  print "Done\n";
}  

sub TagMain {
  my $tag=shift;

  print "Tagging netforts ...";
  system("$::svn copy -m \"$::myname: Creating $tag\" . svn+ssh://$::host/$::path/netforts/tags/$tag >/dev/null 2>&1"); 
  my $exit_code_netforts = $? >> 8;
  if($exit_code_netforts ) {
    die "There was an error when tagging netforts: $!\n.";
  } else {
    print "Done\n";
  }

  print "Tagging fms ...";
  chdir("fms");
  system("$::svn copy -m \"$::myname: Creating $tag\" . svn+ssh://$::host/$::path/fms/tags/$tag >/dev/null 2>&1");
  my $exit_code_fms = $? >> 8;
  if($exit_code_fms) {
    die "There was an error when tagging fms: $!\n.";
  } else {
    print "Done\n";
  }
  chdir("..");
}

sub UpdatePropset
{
  my $tag=shift;

  print "Updating external propset ...";
  system("$::svn co -N svn+ssh://$::host/$::path/netforts/tags/$tag $tag >/dev/null 2>&1");
  my $exit_code_netforts = $? >> 8;
  die "There was an error checking out the old propset: $!\n" if $exit_code_netforts;
  copy("svn-externals.new","$tag/svn-externals") || die "Couldn't move new svn-externals into place:$!\n";
  chdir("$tag");
  system("$::svn propset svn:externals -F svn-externals . >/dev/null 2>&1");
  my $exit_code_copy= $? >> 8;
  die "There was an error checking out the old propset: $!\n" if $exit_code_copy;
  die "Couldn't propset: $!\n" if $exit_code_copy;
  system("$::svn commit -m \"svn-externals set for new branch $tag\" >/dev/null 2>&1"); 
  my $exit_code_ci= $? >> 8;
  die "Couldn't commit new propset: $!\n" if $exit_code_ci;
  chdir("..");
  print "Done\n";
}  
  
#Main
{
  my %opts;
  my @externals;
  our $svn = '/usr/bin/svn';
  our $host = 'babylon.eng.fireeye.com';
  our $path = 'ws/svnroot';
  our $myname=basename($0);

  getopts('ht:',\%opts);
  &Usage unless %opts;
  &Help if defined $opts{'h'};
  &CheckName($opts{'t'});
  @externals = &GetExternals;
  &CheckSpace(\@externals);
#  &CheckTag($opts{'t'});
#  &TagMain($opts{'t'});
  &TagExternals($opts{'t'},\@externals);
# &UpdatePropset($opts{'t'});
  print "Tag completed.\n";
}
