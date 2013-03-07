#!perl

use Test::More;
do "t/common.pl";

###################################################################
# SLURP

ok_plugin(0, "SLURP OK - slurped as scalar", undef, "Output is scalar", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	PLUGIN name => 'SLURP';
	START default => 'slurped as scalar';

	my $scalar_output = SLURP("t/data/slurp/normal");
		CRITICAL "output of slurp is not scalar: \"".chomp($scalar_output)."\""
			unless "first line\nsecond line\n" eq $scalar_output;
	DONE;
});

ok_plugin(0, "SLURP OK - slurped as array", undef, "Output is array", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	use Test::Deep::NoTest;
	PLUGIN name => 'SLURP';
	START default => 'slurped as array';

	my @array_test   = ("first line", "second line");
	my @array_output = SLURP("t/data/slurp/normal");
	my $error_string = join(", ", @array_output);
	my $test_string  = join(", ", @array_test);

	CRITICAL "Output is not array: \"".$error_string."\" does not match test: \"".$test_string."\"" unless eq_deeply(\@array_test, \@array_output,"slurped as array");
	DONE;
});

ok_plugin(0, "SLURP OK - undef input", undef, "Undef SLURP", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	PLUGIN name => 'SLURP';
	START default => 'undef input';

	my $output = SLURP(undef);

	CRITICAL "Output is defined when there should be none" if defined($output);
	DONE;
});

ok_plugin(0, "SLURP OK - null input", undef, "Null SLURP", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	PLUGIN name => 'SLURP';
	START default => 'null input';

	my $output = SLURP("");

	CRITICAL "Not null output when there should be none" if defined($output);
	DONE;
});

ok_plugin(0, "SLURP OK - File not found", undef, "File not found", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	PLUGIN name => 'SLURP';
	START default => "File not found";

	my $output = SLURP("missing-input");

	CRITICAL "Found output when there should be none" if defined $output;
	DONE;
});

ok_plugin(0, "SLURP OK - File unreadable", undef, "File unreadable", sub {
	use strict;
	use Synacor::SynaMon::Plugin qw(:easy);
	PLUGIN name => "SLURP";
	START default => "File unreadable";

	chmod 0000, "data/slurp/unreadable";
	my $output = SLURP("data/slurp/unreadable");
	chmod 0644, "data/slurp/unreadable";

	CRITICAL "Output from unreadable input" if defined $output;
	DONE;
});

done_testing;
