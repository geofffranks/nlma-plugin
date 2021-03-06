package NLMA::Plugin::Easy;

use strict;
use warnings;

use NLMA::Plugin::Base;

use Exporter;
use base qw(Exporter);

our @EXPORT = qw/
	PLUGIN OPTION

	SET

	STATUS BAIL EVALUATE
	OK WARNING CRITICAL UNKNOWN

	START DONE
	ON_TERMINATE

	CHECK_VALUE TRACK_VALUE ANALYZE_THOLD

	STAGE START_TIMEOUT STOP_TIMEOUT
	STAGE_TIME TOTAL_TIME

	STORE RETRIEVE SLURP STATE_FILE_PATH
	CREDENTIALS CRED_KEYS

	RUN LAST_RUN_EXITED LAST_RUN_EXIT_REASON
	SSH

	MECH
	HTTP_REQUEST
	HTTP_GET
	HTTP_POST
	HTTP_PUT
	SUBMIT_FORM

	JSON_DECODE

	PARSE_BYTES FORMAT_BYTES BYTES_THOLD
	PARSE_TIME  FORMAT_TIME  TIME_THOLD

	JOLOKIA_CONNECT
	JOLOKIA_READ
	JOLOKIA_SEARCH

	SAR
	CALC_RATE

	DEVNAME

	SNMP_MIB SNMP_SESSION
	SNMP_GET SNMP_TREE SNMP_TABLE
	OID OIDS
	SNMP_ENUM SNMP_TC

	RRD

	DB_CONNECT DB_QUERY DB_EXEC

	DEBUG DUMP NOOP
	TRACE TDUMP
/;

our $plugin;

sub PLUGIN  { $plugin = NLMA::Plugin::Base->new(@_); }
sub OPTION  { $plugin->option(@_); }

sub SET { $plugin->set(@_); }

sub STATUS   { $plugin->status(@_); }
sub BAIL     { $plugin->bail(@_); }
sub EVALUATE { $plugin->evaluate(@_); }

sub OK       { $plugin->OK(@_); }
sub WARNING  { $plugin->WARNING(@_); }
sub CRITICAL { $plugin->CRITICAL(@_); }
sub UNKNOWN  { $plugin->UNKNOWN(@_); }

sub CHECK_VALUE   { $plugin->check_value(@_); }
sub TRACK_VALUE   { $plugin->track_value(@_); }
sub ANALYZE_THOLD { $plugin->analyze_thold(@_); }

sub START { $plugin->start(@_); }
sub DONE  { $plugin->done(@_); }
sub ON_TERMINATE { $plugin->on_terminate(@_) };

sub STAGE { $plugin->stage(@_); }
sub START_TIMEOUT { $plugin->start_timeout(@_); }
sub STOP_TIMEOUT  { $plugin->stop_timeout(@_); }
sub STAGE_TIME { $plugin->stage_time(@_); }
sub TOTAL_TIME { $plugin->total_time(@_); }

sub STORE { $plugin->store(@_); }
sub RETRIEVE { $plugin->retrieve(@_); }
sub SLURP { $plugin->slurp(@_); }
sub STATE_FILE_PATH { $plugin->state_file_path(@_); }

sub CREDENTIALS { $plugin->credentials(@_); }
sub CRED_KEYS { $plugin->cred_keys(@_); }

sub RUN { $plugin->run(@_); }
sub LAST_RUN_EXITED { $plugin->last_run_exited(@_); }
sub LAST_RUN_EXIT_REASON { $plugin->last_run_exit_reason(@_); }
sub SSH { $plugin->ssh(@_); }

sub DEBUG { $plugin->debug(@_) if $plugin }
sub DUMP  { $plugin->dump(@_); }
sub NOOP  { $plugin->noop(@_); }
sub TRACE { $plugin->trace(@_) if $plugin }
sub TDUMP { $plugin->trace_dump(@_); }

sub MECH         { $plugin->mech(@_); }
sub HTTP_REQUEST { $plugin->http_request(@_); }
sub HTTP_GET     { $plugin->http_get(@_); }
sub HTTP_PUT     { $plugin->http_put(@_); }
sub HTTP_POST    { $plugin->http_post(@_); }
sub SUBMIT_FORM  { $plugin->submit_form(@_); }

sub JSON_DECODE { $plugin->json_decode(@_); }

sub PARSE_BYTES  { $plugin->parse_bytes(@_); }
sub FORMAT_BYTES { $plugin->format_bytes(@_); }
sub BYTES_THOLD
{
	my ($thold) = @_;
	if ($thold) {
		DEBUG "Converting human-readable size specs in '$thold'";
		$thold =~ s/\s*(\d+(?:\.\d+)?)\s*([kmgtpezy]?b)/PARSE_BYTES("$1$2")/egi;
		DEBUG "Converted threshold to '$thold'";
	}
	return $thold;
}

sub PARSE_TIME  { $plugin->parse_time(@_); }
sub FORMAT_TIME { $plugin->format_time(@_); }
sub TIME_THOLD
{
	my ($thold) = @_;
	if ($thold) {
		DEBUG "Converting human-readable time specs in '$thold'";
		$thold =~ s/\s*(\d+(?:\.\d+)?)\s*([mhd])\b/PARSE_TIME("$1$2")/egi;
		DEBUG "Converted threshold to '$thold'";
	}
	return $thold;
}

sub JOLOKIA_CONNECT { $plugin->jolokia_connect(@_); }
sub JOLOKIA_READ    { $plugin->jolokia_read(@_); }
sub JOLOKIA_SEARCH  { $plugin->jolokia_search(@_); }

sub SAR { $plugin->sar(@_); }
sub CALC_RATE { $plugin->calculate_rate(@_); }

sub DEVNAME { $plugin->devname(@_); }

sub SNMP_MIB     { $plugin->snmp_mib(@_); }
sub SNMP_SESSION { $plugin->snmp_session(@_); }
sub SNMP_GET     { $plugin->snmp_get(@_); }
sub SNMP_TREE    { $plugin->snmp_tree(@_); }
sub SNMP_TABLE   { $plugin->snmp_table(@_); }
sub OID          { $plugin->oid(@_); }
sub OIDS         { $plugin->oids(@_); }
sub SNMP_ENUM    { $plugin->snmp_enum(@_); }
sub SNMP_TC      { $plugin->snmp_tc(@_); }

sub RRD          { $plugin->rrd(@_); }

sub DB_CONNECT   { $plugin->db_connect(@_); }
sub DB_QUERY     { $plugin->db_query(@_); }
sub DB_EXEC      { $plugin->db_exec(@_); }

END {
	$plugin->finalize("END block") if $plugin;
	$plugin->done if $plugin && !$NLMA::Plugin::Base::ALL_DONE;
}

1;

=head1 NAME

NLMA::Plugin::Easy - Simple Plugin API

=head1 DESCRIPTION

The B<Plugin::Easy> interface is an alternative to the object-oriented
B<Plugin> package.  It operates on a global plugin object, and helps
writer cleaner scripts.  It is not as flexible as the OO interface, but
should suffice for most check plugins.

It is also easier to read a B<Plugin::Easy> check than an OO check.

In general, procedures map directly to methods in the B<Plugin> package,
except that the procedural varieties are in upper case.  For example,
B<STORE(...)> is the same as B<$plugin->store(...)>.

See B<NLMA::Plugin> for in-depth documentation.

=head1 METHODS

=head2 PLUGIN

Sets up the global plugin context.  This B<must> be called first, as
soon as possible.  None of the other functions will work otherwise.

Arguments are identical to B<NLMA::Plugin::new>

=head2 SET

Wrapper around B<NLMA::Plugin::set>.

=head2 OPTION

Wrapper around B<NLMA::Plugin::option>.

=head2 STATUS

Wrapper around B<NLMA::Plugin::status>.

=head2 BAIL

Wrapper around B<NLMA::Plugin::bail>.

=head2 EVALUATE

Wrapper around B<NLMA::Plugin::evaluate>.

=head2 OK

Wrapper around B<NLMA::Plugin::OK>.

=head2 WARNING

Wrapper around B<NLMA::Plugin::WARNING>.

=head2 CRITICAL

Wrapper around B<NLMA::Plugin::CRITICAL>.

=head2 UNKNOWN

Wrapper around B<NLMA::Plugin::UNKNOWN>.

=head2 ANALYZE_THOLD

Wrapper around B<NLMA::Plugin::analyze_thold>.

=head2 CHECK_VALUE

Wrapper around B<NLMA::Plugin::check_value>.

=head2 TRACK_VALUE

Wrapper around B<NLMA::Plugin::track_value>.

=head2 START

Wrapper around B<NLMA::Plugin::start>.

=head2 DONE

Wrapper around B<NLMA::Plugin::done>.

=head2 ON_TERMINATE

Wrapper around B<NLMA::Plugin::on_terminate>.

=head2 STAGE

Wrapper around B<NLMA::Plugin::stage>.

=head2 START_TIMEOUT

Wrapper around B<NLMA::Plugin::start_timer>.

=head2 STOP_TIMEOUT

Wrapper around B<NLMA::Plugin::stop_timer>.

=head2 STAGE_TIME

Wrapper around B<NLMA::Plugin::stage_time>.

=head2 TOTAL_TIME

Wrapper around B<NLMA::Plugin::total_time>.

=head2 SLURP

Wrapper around B<NLMA::Plugin::slurp>.

=head2 STORE

Wrapper around B<NLMA::Plugin::store>.

=head2 RETRIEVE

Wrapper around B<NLMA::Plugin::retrieve>.

=head2 CREDENTIALS

Wrapper around B<NLMA::Plugin::credentials>.

=head2 CRED_KEYS

Wrapper around B<NLMA::Plugin::cred_keys>.

=head2 STATE_FILE_PATH

Wrapper around B<NLMA::Plugin::state_file_path>.

Introduced in 1.09

=head2 RUN

Wrapper around B<NLMA::Plugin::run>.

=head2 LAST_RUN_EXITED

Wrapper around B<NLMA::Plugin::last_run_exited>.

=head2 LAST_RUN_EXIT_REASON

Wrapper around B<NLMA::Plugin::last_run_exit_reason>.

=head2 SSH

Wrapper around B<NLMA::Plugin::ssh>.

=head2 DEBUG

Wrapper around B<NLMA::Plugin::debug>.

=head2 DUMP

Wrapper around B<NLMA::Plugin::dump>.

=head2 NOOP

Wrapper around B<NLMA::Plugin::noop>.

=head2 TRACE

Wrapper around B<NLMA::Plugin::trace>.

=head2 TDUMP

Wrapper around B<NLMA::Plugin::trace_dump>.

=head2 MECH

Wrapper around B<NLMA::Plugin::mech>.

=head2 HTTP_REQUEST

Wrapper around B<NLMA::Plugin::http_request>.

=head2 HTTP_GET

Wrapper around B<NLMA::Plugin::http_get>.

=head2 HTTP_PUT

Wrapper around B<NLMA::Plugin::http_put>.

=head2 HTTP_POST

Wrapper around B<NLMA::Plugin::http_post>.

=head2 SUBMIT_FORM

Wrapper around B<NLMA::Plugin::submit_form>.

=head2 JSON_DECODE

Wrapper around B<NLMA::Plugin::json_decode>.

=head2 PARSE_BYTES

Wrapper around B<NLMA::Plugin::parse_bytes>.

=head2 FORMAT_BYTES

Wrapper around B<NLMA::Plugin::format_bytes>.

=head2 BYTES_THOLD

Convert human-readable size specs in a threshold (like "4kb:8kb")
and turns them into raw byte thresholds, (i.e. "4096:8192").

Otherwise, the threshold string will remain as-is.

=head2 PARSE_TIME

Wrapper around B<NLMA::Plugin::parse_time>.

=head2 FORMAT_TIME

Wrapper around B<NLMA::Plugin::format_time>.

=head2 TIME_THOLD

Convert human-readable time specs in a threshold (like "5m:10m")
and turns them into raw time thresholds in seconds, (i.e. "300:600").

Otherwise, the threshold string will remain as-is.

=head2 JOLOKIA_CONNECT

Wrapper around B<NLMA::Plugin::jolokia_connect>.

=head2 JOLOKIA_READ

Wrapper around B<NLMA::Plugin::jolokia_read>.

=head2 JOLOKIA_SEARCH

Wrapper around B<NLMA::Plugin::jolokia_search>.

=head2 SAR

Wrapper around B<NLMA::Plugin::sar>.

=head2 DEVNAME

Wrapper around B<NLMA::Plugin::devname>.

=head2 CALC_RATE

Wrapper around B<NLMA::Plugin::calculate_rate>.

=head2 SNMP_MIB

Wrapper around B<NLMA::Plugin::snmp_mib>.

=head2 SNMP_SESSION

Wrapper around B<NLMA::Plugin::snmp_session>.

=head2 SNMP_GET

Wrapper around B<NLMA::Plugin::snmp_get>.

=head2 SNMP_TREE

Wrapper around B<NLMA::Plugin::snmp_tree>.

=head2 SNMP_TABLE

Wrapper around B<NLMA::Plugin::snmp_table>.

=head2 OID

Wrapper around B<NLMA::Plugin::oid>.

=head2 OIDS

Wrapper around B<NLMA::Plugin::oids>.

=head2 SNMP_ENUM

Wrapper around B<NLMA::Plugin::snmp_enum>.

=head2 SNMP_TC

Wrapper around B<NLMA::Plugin::snmp_tc>.

=head2 RRD

Wrapper around B<NLMA::Plugin::rrd>.

=head2 DB_CONNECT

Wrapper around B<NLMA::Plugin::db_connect>.

=head2 DB_QUERY

Wrapper around B<NLMA::Plugin::db_query>.

=head2 DB_EXEC

Wrapper around B<NLMA::Plugin::db_exec>.

=head1 AUTHOR

James Hunt, C<< <jhunt@synacor.com> >>

=cut

