#!perl

use Test::More;
do "t/common.pl";
use Test::LongString;

use constant TEST_SEND_NSCA => "t/bin/send_nsca";
use constant TEST_NSCA_OUT  => "t/tmp/nsca.out";

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
	use Synacor::SynaMon::Plugin qw(:feeder);
	PLUGIN name => "feeder";
	OK "good";
});

###################################################################
# send_nsca - bad exec

ok_plugin(3, "FEEDER UNKNOWN - Failed to exec t/bin/enoent: No such file or directory", undef, "SEND_NSCA / bad exec", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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
# send_nsca - broken pipe

ok_plugin(2, "FEEDER CRITICAL - broken pipe: check send_nsca command", undef, "SEND_NSCA / broken pipe", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin => "/bin/true";

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "WARNING",
	          output   => "Kinda High...";

	OK "sent";
});

###################################################################
# send_nsca - one chunk

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA a few times", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         BOGUS  => "this is a bogus option",
	         config => TEST_NSCA_OUT;

	SEND_NSCA host     => "a-host",
	          status   => "DOWN",
	          output   => "its broke!";

	SEND_NSCA host     => "a-host",
	          service  => "cpu",
	          status   => "CRITICAL",
	          output   => "Kinda High...";

	OK "sent";
});
is_string_nows(slurp(TEST_NSCA_OUT),
	"[[starting]]\n".
	"a-host\t1\tits broke!\n\x17".
	"a-host\tcpu\t2\tKinda High...\n\x17",
		"send_nsca output is correct");

###################################################################
# send_nsca - bad status vals

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA / bad status", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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
	"[[starting]]\n".
	"host\tservice\t3\tits broke!\n\x17".
	"host\tservice\t3\tits broke!\n\x17".
	"host\tservice\t3\tits broke!\n\x17",
		"send_nsca output is correct");

###################################################################
# send_nsca - noop

unlink TEST_NSCA_OUT;
system("touch ".TEST_NSCA_OUT);
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA noop", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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
# send_nsca - two chunks

unlink TEST_NSCA_OUT;
ok_plugin(0, "FEEDER OK - sent", undef, "SEND_NSCA lots of times", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
	PLUGIN name => "feeder";
	START;
	SET_NSCA bin    => TEST_SEND_NSCA,
	         config => TEST_NSCA_OUT,
	         max    => 7;

	for (my $i = 0; $i < 45; $i++) {
		SEND_NSCA host     => "host",
		          service  => "service",
		          status   => "CRITICAL",
		          output   => "its broke!";
	}

	OK "sent";
});
my $s = "";
for (my $i = 0; $i < 45; $i++) {
	$s .= "[[starting]]\n" if $i % 7 == 0;
	$s .= "host\tservice\t2\tits broke!\n\x17";
}
is_string_nows(slurp(TEST_NSCA_OUT), $s,
	"send_nsca output is correct for re-exec'd runs");

###################################################################
# send_nsca - bad exit subchild

ok_plugin(2, "FEEDER CRITICAL - t/bin/die exited with code 4", undef, "SEND_NSCA bin exits non-zero", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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

ok_plugin(2, "FEEDER CRITICAL - t/bin/die exited with code 4", undef, "SEND_NSCA bin exits non-zero (with DONE)", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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
});

ok_plugin(2, "FEEDER CRITICAL - t/bin/die killed by signal 15", undef, "SEND_NSCA bin killed", sub {
	use Synacor::SynaMon::Plugin qw(:feeder);
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
# cleanup

unlink TEST_NSCA_OUT;
done_testing;
