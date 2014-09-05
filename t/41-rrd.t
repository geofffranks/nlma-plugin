#!perl

use Test::More;
require "t/common.pl";

# Verify default settings
ok_plugin(0, "RRD OK", undef, "Default RRD settings are set", sub {
	use Synacor::SynaMon::Plugin qw/:easy/;
	PLUGIN name => "rrd";

	my $settings = $Synacor::SynaMon::Plugin::Easy::plugin->{settings};

	CRITICAL "Bad default rrd_binary setting: '$settings->{rrd_binary}'."
		unless $settings->{rrd_binary} eq "/usr/bin/rrdtool";
	CRITICAL "Bad default rrd_base setting: '$settings->{rrd_base}'."
		unless $settings->{rrd_base} eq "/opt/synacor/monitor/rrd";
	CRITICAL "Bad default rrd_cached_socket setting: '$settings->{rrd_cached_socket}'."
		unless $settings->{rrd_cached_socket} eq "unix:/var/run/rrdcached/rrdcached.sock";
	CRITICAL "Bad default rrd_on_failure setting: '$settings->{rrd_on_failure}'."
		unless $settings->{rrd_on_failure} == 2;
	CRITICAL "Bad default rrd_fail_bail setting: '$settings->{rrd_fail_bail}'."
		unless $settings->{rrd_fail_bail} == 1;

	OK;
	DONE;
});

# Verify settings can be overridden
ok_plugin(0, "RRD OK", undef, "RRD settings can be overridden", sub {
	use Synacor::SynaMon::Plugin qw/:easy/;
	PLUGIN name => "rrd";

	my $settings = $Synacor::SynaMon::Plugin::Easy::plugin->{settings};

	SET rrd_binary        => "t/tmp/rrdtool";
	SET rrd_base          => "t/data/rrd";
	SET rrd_cached_socket => "unix:t/tmp/rrdcached.sock";
	SET rrd_on_failure    => 1;
	SET rrd_fail_bail     => 0;

	CRITICAL "Bad overridden rrd_binary setting: '$settings->{rrd_binary}'."
		unless $settings->{rrd_binary} eq "t/tmp/rrdtool";
	CRITICAL "Bad overridden rrd_base setting: '$settings->{rrd_base}'."
		unless $settings->{rrd_base} eq "t/data/rrd";
	CRITICAL "Bad overridden rrd_cached_socket setting: '$settings->{rrd_cached_socket}'."
		unless $settings->{rrd_cached_socket} eq "unix:t/tmp/rrdcached.sock";
	CRITICAL "Bad overridden rrd_on_failure setting: '$settings->{rrd_on_failure}'."
		unless $settings->{rrd_on_failure} == 1;
	CRITICAL "Bad overridden rrd_on_fail_bail setting: '$settings->{rrd_fail_bail}'."
		unless $settings->{rrd_fail_bail} == 0;

	OK;
	DONE;
});

# Verify RRD works under nominal circumstances
ok_plugin(0, "RRD OK", undef, "RRD can fetch data", sub {
	use Synacor::SynaMon::Plugin qw/:easy/;
	PLUGIN name => "rrd";

	SET rrd_base          => "t/data/rrd";
	SET rrd_cached_socket => "unix:t/tmp/nosckethere.sock";

	my $data = RRD "info", "test";
	CRITICAL "No data returned from RRD" unless $data;

	OK;
	DONE;
});

# Verify RRD calls set up the RRDCACHED_ADDRESS env variable
ok_plugin(0, "RRD OK", undef, "RRD sets RRDCACHED_ADDRESS environment variable", sub {
	use Synacor::SynaMon::Plugin qw/:easy/;
	PLUGIN name => "rrd";

	SET rrd_base          => "t/data/rrd";
	SET rrd_cached_socket => "unix:t/tmp/nosockethere.sock";

	RRD "info", "test";
	CRITICAL "RRDCACHED_ADDRESS=$ENV{RRDCACHED_ADDRESS} - that's bad"
		unless $ENV{RRDCACHED_ADDRESS} eq "unix:t/tmp/nosockethere.sock";

	OK;
	DONE;
});

# Verify Multiple RRD calls don't cause problems. (RRDp will croak)
ok_plugin(0, "RRD OK", undef, "multiple RRD calls don't cause failure", sub {
	use Synacor::SynaMon::Plugin qw/:easy/;
	PLUGIN name => "rrd";

	SET rrd_base          => "t/data/rrd";
	SET rrd_cached_socket => "unix:t/tmp/nosckethere.sock";

	RRD "info", "test";
	RRD "info", "test";

	OK;
	DONE;
});

# Verify Errors are caught/handled appropriately
ok_plugin(2, "RRD CRITICAL - ERROR: opening 't/data/rrd/norrdhere.rrd': No such file or directory.",
	undef,
	"RRD errors are handled appropriately", sub {
		use Synacor::SynaMon::Plugin qw/:easy/;
		PLUGIN name => "rrd";

		SET rrd_base => "t/data/rrd";

		RRD "info", "norrdhere";

		UNKNOWN "Shouldn't get here, as RRD will bail";
		DONE;
});

# Setting fail_bail = 0 allows scripts to continue
ok_plugin(2,
	"RRD CRITICAL - ERROR: opening 't/data/rrd/norrdhere.rrd': No such file or directory. Second message",
	undef, "RRD fail_bail = 0 allows continued execution", sub {
		use Synacor::SynaMon::Plugin qw/:easy/;
		PLUGIN name => "rrd";

		SET rrd_base      => "t/data/rrd";
		SET rrd_fail_bail => 0;

		RRD "info", "norrdhere";

		CRITICAL "Second message";
		DONE;
});

# Customizing on_failure affects status messages
ok_plugin(1, "RRD WARNING - ERROR: opening 't/data/rrd/norrdhere.rrd': No such file or directory.",
	undef, "RRD on_failure adjusts status properly", sub {
		use Synacor::SynaMon::Plugin qw/:easy/;
		PLUGIN name => "rrd";

		SET rrd_base       => "t/data/rrd";
		SET rrd_on_failure => "WARNING";

		RRD "info", "norrdhere";

		UNKNOWN "Shouldn't get here, as RRD will bail";
		DONE;
});

done_testing;
