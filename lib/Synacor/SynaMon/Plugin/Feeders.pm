package Synacor::SynaMon::Plugin::Feeders;

use Synacor::SynaMon::Plugin::Base;
use Synacor::SynaMon::Plugin::Easy;
use POSIX qw/WEXITSTATUS WTERMSIG WIFEXITED WIFSIGNALED/;
use Log::Log4perl;

use Exporter;
use base qw(Exporter);

our @EXPORT = qw/
	SET_NSCA
	SEND_NSCA
	FLUSH_NSCA

	LOG
/;

use constant HT_LOG_CONFIG => "/opt/synacor/monitor/etc/htlog.conf";

my @RESULTS = ();
my $LOG;
my %NSCA = (
	chunk  => "/opt/synacor/monitor/bin/chunk",
	bin    => "/usr/bin/send_nsca",
	host   => "localhost",
	config => "/etc/icinga/send_nsca.cfg",
	port   => "5667",
	args   => "",
	max    => 700,
	noop   => 0,
);

##########################################################

sub SET_NSCA
{
	my (%C) = @_;
	for (keys %C) {
		next unless exists $NSCA{$_};
		DEBUG "Setting $_ => $C{$_} (was $NSCA{$_})";
		$NSCA{$_} = $C{$_};
	}
}

sub FLUSH_NSCA
{
	return unless @RESULTS;
	my $chunk = "$NSCA{chunk} -L $NSCA{max}";
	my $cmd = "$NSCA{bin} -H $NSCA{host} -c $NSCA{config} -p $NSCA{port} $NSCA{args}";
	if ($NSCA{noop}) {
		DEBUG "NOOP `$chunk -- $cmd`";
		DEBUG "NOOP >> '$_\\n\\x17'\n" for @RESULTS;
		return;
	}

	DEBUG "Executing `$chunk -- $cmd`";
	-x $NSCA{bin} or UNKNOWN "$NSCA{bin}: $!";

	open my $pipe, "|-", "$chunk -- $cmd"
		or BAIL "Exec failed: $!";

	for (@RESULTS) {
		DEBUG "NSCA >> '$_\\n\\x17'\n";
		print $pipe "$_\n\x17"
			or BAIL "SEND_NSCA failed: $!";
	}
	close $pipe;
	$rc = $?;
	return if $rc == 0;
	if (WIFEXITED($rc)) {
		$rc = WEXITSTATUS($rc);
		CRITICAL "sub-process exited with code $rc";
	} elsif (WIFSIGNALED($rc)) {
		$rc = WTERMSIG($rc);
		CRITICAL "sub-process killed by signal $rc";
	} else {
		$rc = sprintf("0x%04x", $rc);
		CRITICAL "sub-process terminated abnormally with code ($rc)";
	}
}

sub SEND_NSCA
{
	my (%args) = @_;
	$args{status} = $Synacor::SynaMon::Plugin::Base::STATUS_CODES{$args{status}};
	$args{status} = 3 if !defined($args{status});

	if (exists $args{service}) {
		push @RESULTS, "$args{host}\t$args{service}\t$args{status}\t$args{output}";
	} else {
		push @RESULTS, "$args{host}\t$args{status}\t$args{output}";
	}
}

sub LOG
{
	return $LOG if $LOG;

	if (OPTION->debug) {
		$ENV{HT_DEBUG} = "DEBUG";
	}

	my $service = $Synacor::SynaMon::Plugin::Easy::plugin->{name};
	DEBUG "Setting up Log4perl for $service";

	my $config = $ENV{HT_LOG_CONFIG} || HT_LOG_CONFIG;
	if (-f $config) {
		Log::Log4perl::init_and_watch($config, 'HUP');
	} else {
		my $literal = q|
			log4perl.rootLogger = WARN, DEFAULT
			log4perl.appender.DEFAULT = Log::Log4perl::Appender::Screen
			log4perl.appender.DEFAULT.layout = Log::Log4perl::Layout::PatternLayout
			log4perl.appender.DEFAULT.layout.ConversionPattern = :: [%P] %p: %m%n
		|;
		Log::Log4perl::init(\$literal);
	}
	$LOG = Log::Log4perl->get_logger($service);

	if (OPTION->debug) {
		$LOG->level("DEBUG");
		$LOG->debug("DEBUG logging initiated by user '$ENV{USER}' via --debug flag");
	} elsif ($ENV{HT_DEBUG}) {
		$LOG->level("DEBUG");
		$LOG->debug("DEBUG logging initiated by user '$ENV{USER}' via HT_DEBUG environment variable");
	}

	if ($ENV{HT_TRACE}) {
		$LOG->level("TRACE");
		$LOG->debug("TRACE logging initiated by user '$ENV{USER}' via HT_TRACE environment variable");
	}

	$LOG->info("Logger subsystem initialized from $config");
	return $LOG;
}

END {
	if ($Synacor::SynaMon::Plugin::MODE eq "feeder") {
		DEBUG "Flushing ".@RESULTS." NSCA results\n";
		FLUSH_NSCA;
	}
}

1;

=head1 NAME

Synacor::SynaMon::Plugin::Feeders - Framework for Feeder Plugins

=head1 DESCRIPTION

Feeder plugins are a special breed of monitoring plugin that only run on the
Hammer Throw core servers, and feed results for all hosts monitored by that
node.

=head1 FUNCTIONS

=head2 SEND_NSCA %details

Submit a single result via the send_nsca utility.  This operation is
specifically tuned for bulk submission, which is what most feeders do.

The B<%details> hash should contain the following keys:

=over

=item B<host>

=item B<service> (optional)

=item B<status>

=item B<output>

=back

B<NOTE:> check status can be specified as an integer between 0 and 3,
or as human-readable names like "CRITICAL" and "WARNING".  Unknown

values are treated as 3/UNKNOWN.

=head2 FLUSH_NSCA

Send all batched results to the local monitoring server instance (or
whatever you set I<hostname> to via B<SET_NSCA>).

=head2 LOG

Retrieve a Log::Log4perl object for sending messages to the logging
subsystem.  The logger object returned will be properly memoized and
configured for the executing feeder / environment / debug flags.

=head2 SET_NSCA %settings

Configure the SEND_NSCA function, by specifying the following values:

=over

=item B<chunk>

Absolute path to the chunk utility, for splitting input into appropriately-
sized chunks for processing by multiple send_nsca processes.

Defaults to I</opt/synacor/monitor/bin/chunk>

=item B<bin>

Absolute path to the send_nsca binary.

Defaults to I</usr/bin/send_nsca>

=item B<host>

Hostname or IP address of the host to submit feeder results to.

Defaults to I<localhost>

=item B<config>

Path to the send_nsca configuration file.

Defaults to I</etc/icinga/send_nsca.cfg>

=item B<port>

Port number to connect to.

Defaults to I<5667>

=item B<args>

Extra arguments to pass to send_nsca.

=item B<max>

Maximum number of results to send to a send_nsca process before
re-execing a new one.  This is to work around a bug in either send_nsca
or the NSCA daemon.

Defaults to I<700>.

=item B<noop>

Don't actually send results via send_nsca.  Useful for debugging.

Defaults to I<0> (i.e. not in noop mode).

=back

=head1 AUTHOR

Written by James Hunt <jhunt@synacor.com>

=cut
