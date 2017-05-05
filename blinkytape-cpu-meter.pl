#!/usr/bin/env perl
use Device::BlinkyTape::WS2811;
use Time::HiRes qw(usleep);
use Getopt::Long qw(GetOptions);
use Pod::Usage;

my %OPT = ();
GetOptions(
	\%OPT,
	"help|h!",
	"device|d=s",
	"rate|r=i",
);

Pod::Usage::pod2usage() if $OPT{help};

my $tape = Device::BlinkyTape::WS2811->new(dev => ($OPT{device} || '/dev/ttyACM0'), sleeptime => 50);
my $nleds = 60; # LEDs in the blinkytape
my $rate = $OPT{rate} || 2;   # Number of times per second to refresh; recommend power of 2
my $half = $nleds / 2;
my $stat;
my $oldstat;

$tape->all_off();

while(1) {
	$oldstat = $stat;
	{
		open my $procstat, '<', '/proc/stat';
		$/ = '';
		$stat = <$procstat>;
		close $procstat;
	}
	unless ($oldstat) { sleep 1; next; }

	# TODO generalize for more than two cores

	my (@cores) = $stat =~ /^cpu\d+/mg;
	
	my $a; # current
	my $b; # previous

	foreach my $core (@cores) {
		$a->{$core} = extract($core, $stat);
		$b->{$core} = extract($core, $oldstat);
	}

	my %color = (
		center => [64,64,64],
		sys    => [128,0,128],
		user   => [0,128,128],
		nice   => [0,128,128],
		idle   => [1,1,1],
	);

	my @left;
	foreach $part (qw(center sys user nice idle)) {
		push @left, $color{$part} foreach pixels('cpu0', $a, $b, $part);
	}
	
	my @right;
	foreach $part (qw(center sys user nice idle)) {
		push @right, $color{$part} foreach pixels('cpu1', $a, $b, $part);
	}

	# center zero, grows toward ends
	for $x (1 .. $half) { $tape->send_pixel( @{$left[$half-$x]} ); }
	for $x (1 .. $half) { $tape->send_pixel( @{$right[$x-1]} );    }
	$tape->show();
	usleep 1000000 / $rate;
}

sub extract {
	my ($core, $stat) = @_;
	my ($user, $nice, $sys, $idle) = $stat =~ /^$core\s+(\d+) (\d+) (\d+) (\d+)/m;
	return {core => $core, user => $user, nice => $nice, sys => $sys, idle => $idle};
}

sub pixels {
	my ($core, $a, $b, $what) = @_;
	return 1 if $what eq 'center';
	my $delta = $a->{$core}->{$what} - $b->{$core}->{$what};
	return (1 .. int( ($delta / (100 / $rate)) * $half ));
}

=pod

=head1 NAME

blinkytape-cpu-meter.pl - CPU meter for your BlinkyTape!

=head1 USAGE

	blinkytape-cpu-meter.pl [-h|--help]
	blinkytape-cpu-meter.pl [-d|--device <serial_device>] [-r|--rate <rate_per_second>]

	Device is the devicename of your BlinkyTape. Default is /dev/ttyACM0

	Rate is recommended to be a power of two, between 1 and 8. Default is 2.

=head1 AUTHOR

Aaron Kondziela <aaron@aaronkondziela.com>

=head1 LICENSE

MIT License

Copyright (c) 2017 Aaron Kondziela <aaron@aaronkondziela.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut

