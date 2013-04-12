#!/usr/bin/env perl

# Turn on warnings the best way depending on the Perl version.
BEGIN {
  if ( $] >= 5.006_000)
    { require warnings; import warnings; }                      
  else  
    { $^W = 1; }               
}           

use strict;
use DBI;

sub trim {
    my $text = shift;
    $text =~ s/'/ /g;
    $text =~ s/"/ /g;
    return $text;
}

my $SVNLOOK = "/usr/bin/svnlook";

die "usage: ",__FILE__," REPO_PATH REVISION" unless $#ARGV > 0;

my ($repo,$rev)=@ARGV;

my $dbp = DBI->connect("DBI:Pg:dbname=bugs;host=bugzilla.eng.fireeye.com", 
		    "bugs", "fireeye", {'RaiseError' => 1});

my $author = "Committed by: " .`$SVNLOOK author $repo -r $rev`;
my $viewvcurl = "http://rat.eng.fireeye.com/websvn/revision.php?repname=fireeye&rev=$rev\n";
## my $viewvcurl = "http://vbrat.eng.fireeye.com/viewvc/fireeye?view=revision&revision=$rev\n";
my $msg .= $author . "svn web: " . $viewvcurl;
my $log = `$SVNLOOK log $repo -r $rev`;
$msg .= "Comments: " . $log;

my $files=`$SVNLOOK changed $repo -r $rev`;
$msg .= "\n" . $files;
my @bugs;
my $bugpat = '(scr|bug|bugid|bug-id|issue)s?[:#]?\s*([\d\s,#:=]+)';

while($log =~ /$bugpat/gsi){ @bugs = (@bugs,$2 =~ /\d+/g) }

# print $msg;

my $bug_notfound=0;
foreach my $bug (@bugs) {
    $bug_notfound = 1;
    $msg = trim($msg);
    $dbp->do("insert into longdescs(bug_id, who, bug_when, thetext) VALUES($bug, 861, now(),'$msg')");
} 

my $is_branch = ($files =~ /\/branches\/4\.0\.2\//);

# print "\nbug_notfound: $bug_notfound, is_branch=$is_branch\n";

if (($is_branch) && (!$bug_notfound)) {
    # printf "\nhere\n";
    my $sendmail = "/usr/sbin/sendmail -t";
    my $reply_to = "Reply-to: fireeye-dev\@fireeye.com\n";
    my $subject = "Subject: $author in branch without providing valid bug id in comments\n";
    my $to = "To: fireeye-dev\@fireeye.com\n";
    my $from = "From: fireeye-dev\@fireeye.com\n";
    my $file = "subscribers.txt";
    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
    print SENDMAIL $reply_to;
    print SENDMAIL $subject;
    print SENDMAIL $from;
    print SENDMAIL $to;
    print SENDMAIL "Content-type: text/plain\n\n";
    print SENDMAIL $msg . "\n\nPlease provide \'bug <id>\' in your comments\n";
    close(SENDMAIL);
}

$dbp->disconnect();
