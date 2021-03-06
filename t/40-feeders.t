#!perl

use Test::More;
require "t/common.pl";
use Test::LongString;

use constant TEST_SEND_NSCA => "t/bin/send_nsca";
use constant TEST_NSCA_OUT  => "t/tmp/nsca.out";
use constant TEST_LOG_FILE  => "t/tmp/feeders";
mkdir "t/tmp";

sub slurp
{
	my ($file) = @_;
	open my $fh, "<", $file
		or BAIL_OUT "slurp($file) failed: $!";
	my $actual = do { local $/; <$fh> };
	close $fh;
	return $actual;
}

###################################################################
# feeder plugins

ok_plugin(0, "FEEDER OK - good", undef, "Basic Feeder Plugin", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	OK "good";
});

###################################################################
# send_nsca - bad exec

ok_plugin(3, "FEEDER UNKNOWN - t/bin/enoent: No such file or directory", undef, "SEND_NSCA / bad exec", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin => "t/bin/enoent";
	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "sent";
});

###################################################################
# send_nsca - bad status vals

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA / bad status", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         BOGUS  => "this is a bogus option",
	         config => TEST_NSCA_OUT;

	SEND_NSCA host     => "host",
	          service  => "service",
	          status   => "REALLY-BAD",
	          output   => "its broke!";

	SEND_NSCA host     => "host",
	          service  => "service",
	          status   => "TERRIBLE",
	          output   => "its broke!";

	SEND_NSCA host     => "host",
	          service  => "service",
	          status   => 6,
	          output   => "its broke!";

	OK "sent";
});
is_string_nows(slurp(TEST_NSCA_OUT),
	"host\tservice\t3\tits broke!\n\x17".
	"host\tservice\t3\tits broke!\n\x17".
	"host\tservice\t3\tits broke!\n\x17",
		"send_nsca output is correct");

###################################################################
# send_nsca - noop

unlink TEST_NSCA_OUT;
system("touch ".TEST_NSCA_OUT);
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA noop", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         config => TEST_NSCA_OUT,
	         noop   => "yes";

	SEND_NSCA host     => "a-host",
	          service  => "a-service",
	          status   => "CRITICAL",
	          output   => "its broke!";

	OK "sent";
});
is_string_nows(slurp(TEST_NSCA_OUT), "",
		"send_nsca output is correct");

###################################################################
# send_nsca - bad exit subchild

ok_plugin(2, "FEEDER CRITICAL - SEND_NSCA(localhost) sub-process exited with code 4", undef, "SEND_NSCA bin exits non-zero", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin  => "t/bin/die",
	         args => "--exit 4";

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "good";
});

ok_plugin(2, "FEEDER CRITICAL - SEND_NSCA(localhost) sub-process exited with code 4", undef, "SEND_NSCA bin exits non-zero (with DONE)", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin  => "t/bin/die",
	         args => "--exit 4";

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "good";
	DONE;
}, ['-D']);

ok_plugin(2, "FEEDER CRITICAL - SEND_NSCA(localhost) sub-process killed by signal 15", undef, "SEND_NSCA bin killed", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin  => "t/bin/die",
	         args => "--signal TERM";

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "good";
});

###################################################################
# send_nsca - bail after 1 line of input

ok_plugin(2, "FEEDER CRITICAL - SEND_NSCA(localhost) sub-process exited with code 2", undef, "SEND_NSCA / delayed broken pipe", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin   => "t/bin/eat1"; # exits 2 after reading a single line

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	# By now, eat1 has closed STDIN
	# This call to SEND_NSCA should then SIGPIPE
	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "good";
});

###################################################################
# LOGGING

$ENV{NLMA_LOG_CONFIG} = "t/data/feederlog.conf";

unlink TEST_LOG_FILE;
ok_plugin(0, "FEEDER OK - logged", undef, "Feeder Logs", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	LOG->trace("this is a trace message");
	LOG->debug("this is a debug message");
	LOG->info("this is an info message");
	LOG->warn("this is a warning message");
	LOG->error("this is an error message");
	LOG->fatal("this is a fatal message");
	OK "logged";
});
is_string_nows(slurp(TEST_LOG_FILE),
	"WARN: this is a warning message\n".
	"ERROR: this is an error message\n".
	"FATAL: this is a fatal message\n",
		"log messages logged");

unlink TEST_LOG_FILE;
ok_plugin(0, "FEEDER OK - logged", undef, "Feeder Logs -D", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	LOG->trace("this is a trace message");
	LOG->debug("this is a debug message");
	LOG->info("this is an info message");
	LOG->warn("this is a warning message");
	LOG->error("this is an error message");
	LOG->fatal("this is a fatal message");
	OK "logged";
}, ['-D']);
unlike(slurp(TEST_LOG_FILE), qr/^TRACE:/m, "no trace messages in logs");
like(slurp(TEST_LOG_FILE), qr/^DEBUG:/m, "found debugging in logs");
like(slurp(TEST_LOG_FILE), qr/via --debug/m, "found evidence of --debug debugging in logs");

unlink TEST_LOG_FILE;
$ENV{HT_DEBUG} = 1;
ok_plugin(0, "FEEDER OK - logged", undef, "Feeder Logs -D", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	LOG->trace("this is a trace message");
	LOG->debug("this is a debug message");
	LOG->info("this is an info message");
	LOG->warn("this is a warning message");
	LOG->error("this is an error message");
	LOG->fatal("this is a fatal message");
	OK "logged";
});
unlike(slurp(TEST_LOG_FILE), qr/^TRACE:/m, "no trace messages in logs");
like(slurp(TEST_LOG_FILE), qr/^DEBUG:/m, "found debugging in logs");
like(slurp(TEST_LOG_FILE), qr/via HT_DEBUG/m, "found evidence of env var debugging in logs");
delete $ENV{HT_DEBUG};

unlink TEST_LOG_FILE;
$ENV{HT_TRACE} = 1;
ok_plugin(0, "FEEDER OK - logged", undef, "Feeder Logs -D", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	LOG->trace("this is a trace message");
	LOG->debug("this is a debug message");
	LOG->info("this is an info message");
	LOG->warn("this is a warning message");
	LOG->error("this is an error message");
	LOG->fatal("this is a fatal message");
	OK "logged";
});
like(slurp(TEST_LOG_FILE), qr/^TRACE:/m, "found trace messages in logs");
like(slurp(TEST_LOG_FILE), qr/^DEBUG:/m, "found debugging in logs");
like(slurp(TEST_LOG_FILE), qr/via HT_TRACE/m, "found evidence of env var debugging in logs");
delete $ENV{HT_TRACE};

###################################################################
# HOSTS FILE PARSING

ok_plugin(0, "FEEDER OK", undef, "HOSTS file parsing", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	my $file = "t/data/hosts.lst";
	my ($hash, @keys);

	$hash = HOSTS file => $file;
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find 127.0.0.1 => localhost"
		unless $hash->{'127.0.0.1'} and $hash->{'127.0.0.1'} eq 'localhost';

	@keys = HOSTS file => $file;
	WARNING "Did not find 127.0.0.1 in IP list"
		unless $keys[0] and $keys[0] eq "127.0.0.1";

	$hash = HOSTS file => $file, by => 'address';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find 127.0.0.1 => localhost (by => address)"
		unless $hash->{'127.0.0.1'} and $hash->{'127.0.0.1'} eq 'localhost';

	@keys = HOSTS file => $file, by => 'ip';
	WARNING "Did not find 127.0.0.1 in IP list (by => ip)"
		unless $keys[0] and $keys[0] eq "127.0.0.1";


	$hash = HOSTS file => $file, by => 'name';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find localhost => 127.0.0.1"
		unless $hash->{localhost} and $hash->{localhost} eq "127.0.0.1";

	@keys = HOSTS file => $file, by => 'fqdn';
	WARNING "Did not find localhost in Hostname list"
		unless $keys[0] and $keys[0] eq "localhost";


	$hash = HOSTS file => "/path/to/nowhere", alt_file => $file, by => 'name';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find localhost => 127.0.0.1"
		unless $hash->{localhost} and $hash->{localhost} eq "127.0.0.1";

	@keys = HOSTS file => "/path/to/nowhere", alt_file => $file, by => 'fqdn';
	WARNING "Did not find localhost in Hostname list"
		unless $keys[0] and $keys[0] eq "localhost";

	OK;
});

ok_plugin(0, "FEEDER OK", undef, "HOSTS file parsing with extra fields", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	my $file = "t/data/hosts-authoritative.lst";
	my ($hash, @keys);

	$hash = HOSTS file => $file;
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find 127.0.0.1 => localhost"
		unless $hash->{'127.0.0.1'} and $hash->{'127.0.0.1'} eq 'localhost';

	@keys = HOSTS file => $file;
	WARNING "Did not find 127.0.0.1 in IP list"
		unless $keys[0] and $keys[0] eq "127.0.0.1";

	$hash = HOSTS file => $file, by => 'address';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find 127.0.0.1 => localhost (by => address)"
		unless $hash->{'127.0.0.1'} and $hash->{'127.0.0.1'} eq 'localhost';

	@keys = HOSTS file => $file, by => 'ip';
	WARNING "Did not find 127.0.0.1 in IP list (by => ip)"
		unless $keys[0] and $keys[0] eq "127.0.0.1";


	$hash = HOSTS file => $file, by => 'name';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find localhost => 127.0.0.1"
		unless $hash->{localhost} and $hash->{localhost} eq "127.0.0.1";

	@keys = HOSTS file => $file, by => 'fqdn';
	WARNING "Did not find localhost in Hostname list"
		unless $keys[0] and $keys[0] eq "localhost";


	$hash = HOSTS file => "/path/to/nowhere", alt_file => $file, by => 'name';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find localhost => 127.0.0.1"
		unless $hash->{localhost} and $hash->{localhost} eq "127.0.0.1";

	@keys = HOSTS file => "/path/to/nowhere", alt_file => $file, by => 'fqdn';
	WARNING "Did not find localhost in Hostname list"
		unless $keys[0] and $keys[0] eq "localhost";

	OK;
});

ok_plugin(0, "FEEDER OK", undef, "dedupe", sub {
	use NLMA::Plugin qw(:feeder);
	#open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	my $file = "t/data/hosts.dup";
	my $hash;

	$hash = HOSTS file => $file, by => 'name';
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Did not find host1.example.com in deduped, by-name listing"
		unless $hash->{'host1.example.com'} and $hash->{'host1.example.com'} eq '10.10.10.1';
	WARNING "Did not find host2.example.com in deduped, by-name listing"
		unless $hash->{'host2.example.com'} and $hash->{'host2.example.com'} eq '10.10.10.1';

	$hash = HOSTS file => $file, by => 'ip'; # dedupe by default
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	WARNING "Expected 10.10.10.1 => host2.example.com in deduped by-IP listing"
		unless $hash->{'10.10.10.1'} and $hash->{'10.10.10.1'} eq 'host2.example.com';

	$hash = HOSTS file => $file, by => 'ip', dedupe => 0;
	CRITICAL "Received $hash (not a hashref)"
		unless ref($hash) and ref($hash) eq 'HASH';
	CRITICAL "res{10.10.10.1} was not an array ref"
		unless ref($hash->{'10.10.10.1'}) and ref($hash->{'10.10.10.1'}) eq 'ARRAY';
	WARNING "More than two results for 10.10.10.1"
		unless @{$hash->{'10.10.10.1'}} == 2;
	WARNING "Expected 10.10.10.1[0] => host1.example.com in non-deduped, by-IP listing"
		unless $hash->{'10.10.10.1'}[0] and $hash->{'10.10.10.1'}[0] eq 'host1.example.com';
	WARNING "Expected 10.10.10.1[1] => host2.example.com in non-deduped, by-IP listing"
		unless $hash->{'10.10.10.1'}[1] and $hash->{'10.10.10.1'}[1] eq 'host2.example.com';

	CRITICAL "res{127.0.0.1} was not an array ref"
		unless ref($hash->{'127.0.0.1'}) and ref($hash->{'127.0.0.1'}) eq 'ARRAY';
	WARNING "More than one restult for 127.0.0.1"
		unless @{$hash->{'127.0.0.1'}} == 1;
	WARNING "Expected 127.0.0.1[0] => localhost in non-deduped, by-IP listing"
		unless $hash->{'127.0.0.1'}[0] and $hash->{'127.0.0.1'}[0] eq 'localhost';


	OK;
});

ok_plugin(3, "FEEDER UNKNOWN - Failed to open /path/to/nowhere (or /path.alt/to/nowhere): No such file or directory", undef, "bad hosts file", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	HOSTS file => "/path/to/nowhere", alt_file => "/path.alt/to/nowhere";

	OK;
});

ok_plugin(3, "FEEDER UNKNOWN - Failed to open /etc/icinga/defs/local/hosts.lst (or /etc/icinga/defs.old/local/hosts.lst): No such file or directory", undef, "bad hosts file", sub {
	use NLMA::Plugin qw(:feeder);
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;

	HOSTS;

	OK;
});

###################################################################
# CONTEXT

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - sent", undef, "CONTEXT works", sub {
	use NLMA::Plugin qw/:feeder/;
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         BOGUS  => "this is a bogus option",
	         config => TEST_NSCA_OUT;

	CONTEXT  "host1", "cpu";
	WARNING  "warn warn warn";
	CRITICAL "crit crit crit";
	SEND_NSCA;

	CONTEXT  "host2", "load";
	WARNING  "warn warn warn";
	SEND_NSCA;

	CONTEXT  "host3", "memory";
	OK "ok ok ok";
	SEND_NSCA;

	CONTEXT "host4";
	UNKNOWN "host down?";
	SEND_NSCA;

	OK "sent";
});
is_string_nows(slurp(TEST_NSCA_OUT),
	"host1\tcpu\t2\tcrit crit crit\n\x17".
	"host2\tload\t1\twarn warn warn\n\x17".
	"host3\tmemory\t0\tok ok ok\n\x17".
	"host4\t3\thost down?\n\x17",
		"send_nsca output is correct");

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - perfdata", "x=42;;", "CONTEXT handles perfdata", sub {
	use NLMA::Plugin qw/:feeder/;
	open STDERR, ">", "/dev/null";
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         BOGUS  => "this is a bogus option",
	         config => TEST_NSCA_OUT;

	CONTEXT "host1", "cpu";
	TRACK_VALUE x => 1;
	TRACK_VALUE y => 2;
	TRACK_VALUE z => 3;
	OK "good";
	SEND_NSCA;

	TRACK_VALUE x => 42;
	OK "perfdata";
});
is_string_nows(slurp(TEST_NSCA_OUT),
	"host1\tcpu\t0\tgood | x=1;; y=2;; z=3;;\n\x17",
		"send_nsca output is correct");

###################################################################
# cleanup

unlink TEST_LOG_FILE;
unlink TEST_NSCA_OUT;
done_testing;
