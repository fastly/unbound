#!/usr/local/bin/perl -w
use strict;
use POSIX qw(SEEK_END);
use Storable;
use FileHandle;
use Data::Dumper;
use Carp qw(croak carp);
use constant UNBOUND_CACHE => "/var/tmp/unbound-cache.stor";

my $run_from_cron = @ARGV && $ARGV[0] eq "--cron" && shift;
my $DEBUG = -t STDERR;

### if cache exists and  is newer than 3 minutes
if ( -r UNBOUND_CACHE && -M _ < 3/24/60 && !$run_from_cron ) {
	print STDERR "Cached results:\n" if $DEBUG;
	my $result = retrieve(UNBOUND_CACHE);
	print join("\n", @$result), "\n";
	exit;
}

my $logfile = shift or die "Usage: parseunbound.pl --cron unboundlogfile";
my $in = new FileHandle $logfile or die "Cannot open $logfile: $!\n";
$in->seek(-2500, SEEK_END) or croak "cannot seek $logfile: $!\n";

# Stats array containing 1 or more stats hashes.
my @totalstats = ();
# Each stats hash contains name/value pairs of the actual numbers for that thread.
# there is a special key 'thread' that indicates the thread.
my $stats = {};
my $inblock = 0;
my @records = ('thread', 'queries', 'cachehits', 'recursions', 'recursionavg',
		'outstandingmax', 'outstandingavg', 'outstandingexc',
        'median25', 'median50', 'median75',
        'us_0', 'us_1', 'us_2', 'us_4', 'us_8', 'us_16', 'us_32', 'us_64',
        'us_128', 'us_256', 'us_512', 'us_1024', 'us_2048', 'us_4096',
        'us_8192', 'us_16384', 'us_32768', 'us_65536', 'us_131072',
        'us_262144', 'us_524288', 's_1', 's_2', 's_4', 's_8', 's_16',
        's_32', 's_64', 's_128', 's_256', 's_512');


for my $line ( <$in> ) {
	chomp($line);
	#print ">> $line\n";

	if ( !$inblock && $line =~ m/info: server stats for thread (\d+): (\d+) queries, (\d+) answers from cache, (\d+) recursions/ ) {
		$inblock = 1;
		# NB: this clears the previous stats
		$stats = {
			thread => $1,
			queries => $2,
            		cachehits => $3,
			recursions => $4,
		};
		#print STDERR "Parsing stats from thread " . $stats->{thread} . "\n"; 
	}
	elsif ( $inblock && $line =~ m/info: server stats for thread (\d+): requestlist max (\d+) avg ([0-9\.]+) exceeded (\d+)/ ) {
		$stats->{outstandingmax} = $2;
        	$stats->{outstandingavg} = int($3); # This is a float; rrdtool only handles ints.
		$stats->{outstandingexc} = $4;
	}
	if ( $inblock && $line =~ m/info: average recursion processing time ([0-9\.]+) sec/ ) {
        	$stats->{recursionavg} = int($1 * 1000); # change sec to milisec.
	}
	if ( $inblock && $line =~ m/info: histogram of recursion processing times/ ) {
		next;
	}
    	if ( $inblock && $line =~ m/info: \[25%\]=([0-9\.]+) median\[50%\]=([0-9\.]+) \[75%\]=([0-9\.]+)/ ) {
        	$stats->{median25} = int($1 * 1000000); # change seconds to usec
        	$stats->{median50} = int($2 * 1000000);
        	$stats->{median75} = int($3 * 1000000);
	}
    	if ( $inblock && $line =~ m/info: lower\(secs\) upper\(secs\) recursions/ ) {
		next;
	}
	elsif ( $inblock && $line =~ m/info:\s+(\d+)\.(\d+)\s+(\d+)\.(\d+)\s+(\d+)/ ) {
		my ($fromms, $fromus, $toms, $tous, $counter) = ($1, $2, $3, $4, $5);
		my $prefix = '';
		if ($fromms > 0) {
			$stats->{'ms_' . int($fromms)} = $counter;
		} else {
			$stats->{'us_' . int($fromus)} = $counter;
		}
		if ($fromms == '512') {
			$inblock = 0;
			#push @totalstats, $stats;
			# or print $stats.
		}
	}
	else {
		#print STDERR "Cannot parse line: $line (unexpected, inblock=$inblock)\n";
	}
}

if ( ! $stats ) {
	die "Couldn't parse stats?!\n";
}

my @result;
for my $key ( @records ) {
    	$stats->{$key} ||= 0;
    	print STDERR "$key = " . $stats->{$key} . "\n" if $DEBUG;
	push @result, $stats->{$key};
}
print join("\n", @result), "\n";
store \@result, UNBOUND_CACHE;
