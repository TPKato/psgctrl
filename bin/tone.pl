#!/usr/bin/perl

use strict;
use Getopt::Std;

my $fSYS = 1000000;
my $fa = 440;

my $cmdopt = join(" ", @ARGV) || "none";

my %opts;
getopts('f:a:h', \%opts);

if ($opts{'h'}) {
    help();
    exit();
}

sub help {
    print STDERR <<EOH;
Usage: $0 [-h] [-f freq] [-a freq of O4 A]
    -h:        help - show this message and exit
    -f freq:   specify frequency of PSG (in Hz, default: $fSYS)
    -a freq:   specify frequency of O4 A (in Hz, default: $fa)
EOH
}

# ------------------------------------------------------------
my @t = ( "a", "a+", "b", "c", "c+", "d", "d+", "e", "f", "f+", "g", "g+" );

print ";;\n";
print ";; This is auto-generated file by $0.\n";
print ";; (command line option(s): $cmdopt)\n";
print ";;\n";
printf ";; tone data for f_PSG  = %f MHz\n", $fSYS / 1e6;
for (my $o = 1; $o <= 8; $o++) {
    for (my $i = 0; $i < 12; $i++) {
	my $f = $fa * (2 ** (($i + 3)/ 12)) * (2 ** ($o - 5));
	my $TP = int($fSYS / (16 * $f) + 0.5);
	printf ".db 0x%02x, 0x%02x\t; O%d %-2s (%7.2f Hz)", int($TP / 256), $TP % 256, $o, $t[($i + 3) % 12], $f;

	my $fPSG = $fSYS / (16 * $TP);
	my $err = ($fPSG - $f) / $f;
	my $errcent = 1200 * log($fPSG / $f) / log(2);
	printf " (f_PSG: %7.2f Hz, Error %5.2f %% = %7.3f cent)", $fPSG, 100 * $err, $errcent;

	print "\n";
    }
}
