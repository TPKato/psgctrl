#!/usr/bin/perl

# simple MML compiler

use strict;
use Getopt::Std;

my %defaultValues = ( 'O' => 4, 'L' => 4, 'T' => 120, 'V' => 8 );

my $fCPU = 1000000;
my $cmdfile = "./psgplay-commands.asm";

# ------------------------------------------------------------
# command line options

my $cmdopt = join(" ", @ARGV);

my %opts;
getopts('c:f:hd', \%opts);

if ($opts{'h'}) {
    help();
    exit();
}

sub help {
    print STDERR <<EOH;
Usage: $0 [-h] [-d] [-c file] mml-file
    -h:        help - show this message and exit
    -d:        verbose (for debug)
    -f number: specify frequency (in Hz, default: $fCPU)
    -c file:   command file (default: $cmdfile)
EOH
}

if ($#ARGV != 0) {
    print STDERR "Error: MML file is not specified.\n";
    help();
    exit();
}

my $debug = $opts{'d'};
$cmdfile = $opts{'c'} if $opts{'c'};
$fCPU = $opts{'f'} if $opts{'f'};

# ------------------------------------------------------------
# read values from cmdfile

my %cmd;
open(CMD, "<$cmdfile") || die "$cmdfile: $!";
while (<CMD>) {
    s/\s*\;.*$//;
    next if (/^\s*$/);
    chomp;
    s/^\s+//;
    s/\s+$//;

    if (/^\.equ\s+CMD_(\w+)\s*=\s*(\w+)$/) {
	$cmd{$1} = eval($2);
    } elsif (/^\.equ\s+V_DEFAULT\s*=\s*(\w+)$/) {
	$defaultValues{'V'} = eval($1);
    }
}
close(CMD);

# ------------------------------------------------------------
# main routine

my @data;
my $ch = 0;
my $maxch = 3;
my $cntdiff = 0;

my $T = $defaultValues{'T'};
my $o = $defaultValues{'O'};
my $l = $defaultValues{'L'};
my $v = $defaultValues{'V'};

open(MML, "<$ARGV[0]") || die "$!: $ARGV[0]";
print ";;\n";
print ";; This is auto-generated file by $0.\n";
print ";; (command line option(s): $cmdopt)\n";
print ";;\n";
while (<MML>) {
    chomp;

    if (/^\s*$/) {
	if (@data > 0) {
	    print_data($ch, \@data);

	    # reset O, L, V (but not T)
	    $o = $defaultValues{'O'};
	    $l = $defaultValues{'L'};
	    $v = $defaultValues{'V'};

	    @data = ();
	    $ch++;
	    $cntdiff = 0;
	}
	next;
    }

    s/\s*;.*$//;
    s/^\w+:\s*//;
    s/\s+//g;
    next if ($_ =~ /^$/);

    $_ = uc($_);
    my @mml = split(//);
    my $i = 0;
    my $len = $defaultValues{'L'};

    while (1) {
	my $c = $mml[$i];

	if ($c eq "T") {
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		$T = 120;
	    } else {
		$T = 0;
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $T *= 10;
		    $T += $mml[$i + 1] + 0;
		    $i++;
		}
	    }
	    print STDERR "                   ; T=$T\n" if ($debug);

	} elsif ($c eq "L") {
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		$l = 4;
	    } else {
		$l = 0;
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $l *= 10;
		    $l += $mml[$i + 1] + 0;
		    $i++;
		}
	    }
	    print STDERR "                   ; L=$l\n" if ($debug);

	} elsif ($c eq "V") {
	    my $notenum = $cmd{'VOL'};
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		$v = 4;
	    } else {
		$v = 0;
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $v *= 10;
		    $v += $mml[$i + 1] + 0;
		    $i++;
		}
	    }
	    if ($v > 15) {
		$v &= 0x0f;
		print_error($c, "out of range ($c: 0-15). $v will be used");
	    }
	    push(@data, $notenum, $v);

	    if ($debug) {
		printf STDERR "  0x%02x, 0x%02x       ; %s%s\n", $notenum, $v, "V", $v;
	    }
	    next;

	} elsif ($c eq "S") {
	    my $notenum = $cmd{'EnvS'};
	    my $envelope = 0;
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		print_error($c, "no envelope shape is specified")
	    } else {
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $envelope *= 10;
		    $envelope += $mml[$i + 1] + 0;
		    $i++;
		}
	    }
	    if ($envelope > 15) {
		$envelope &= 0x0f;
		print_error($c, "out of range ($c: 0-15). $envelope will be used");
	    }
	    push(@data, $notenum, $envelope);

	    if ($debug) {
		printf STDERR "  0x%02x, 0x%02x       ; %s%s\n", $notenum, $envelope, "S", $envelope;
	    }
	    next;

	} elsif ($c eq "M") {
	    my $notenum = $cmd{'EnvP'};
	    my $envelope = 0;
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		print_error($c, "no envelope period is specified")
	    } else {
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $envelope *= 10;
		    $envelope += $mml[$i + 1] + 0;
		    $i++;
		}
	    }
	    if ($envelope > 65535) {
		$envelope &= 0xffff;
		print_error($c, "out of range ($c: 0-65535). $envelope will be used");
	    }
	    push(@data, $notenum, ($envelope & 0xff00) >> 8, ($envelope & 0xff));

	    if ($debug) {
		printf STDERR "  0x%02x, 0x%02x, 0x%02x ; %s%s\n",
		    $notenum, ($envelope & 0xff00) >> 8, ($envelope & 0xff), "M", $envelope;
	    }
	    next;

	} elsif ($c eq "O") {
	    if (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		$o = $mml[$i + 1] + 0;
		$i++;
	    } else {
		$o = 4;
	    }

	} elsif ($c eq "<") {
	    $o++;

	} elsif ($c eq ">") {
	    $o--;

	} elsif ((("A" le $c) && ($c le "G")) || ($c eq "R") || ($c eq "&")) {
	    my $notenum = noteNumber($o, $c);
	    my $DEBUG_note = $c;

	    if ($c eq "R") {
		$notenum = $cmd{'REST'};
	    } elsif ($c eq "&") {
		$notenum = $cmd{'CONT'};
	    } else {
		# note number
		while (1) {
		    if (($mml[$i + 1] eq "+") || ($mml[$i + 1] eq "#")) {
			$DEBUG_note .= $mml[$i + 1];
			$notenum++;
			$i++;
		    } elsif ($mml[$i + 1] eq "-") {
			$DEBUG_note .= $mml[$i + 1];
			$notenum--;
			$i++;
		    } else {
			last;
		    }
		}
	    }
	    if (! (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9"))) {
		$len = $l;
	    } else {
		$len = 0;
		while (("0" le $mml[$i + 1]) && ($mml[$i + 1] le "9")) {
		    $len *= 10;
		    $len += $mml[$i + 1] + 0;
		    $i++;
		}
	    }

	    my $cnt = noteLength($T, $len);
	    push(@data, $notenum);
	    push(@data, ($cnt & 0xff00) >> 8, ($cnt & 0xff));

	    if ($debug) {
		printf STDERR "  0x%02x, 0x%02x, 0x%02x ; %s%s%s\n",
		    $notenum, ($cnt & 0xff00) >> 8, ($cnt & 0xff),
		    (($c ne "R") && ($c ne "&")) ? "O$o " : "", $DEBUG_note, $len;
	    }

	} elsif ($c eq ".") {
	    $len *= 2;
	    my $cnt = noteLength($T, $len);
	    push(@data, $cmd{'CONT'});
	    push(@data, ($cnt & 0xff00) >> 8, ($cnt & 0xff));

	    if ($debug) {
		printf STDERR "  0x%02x, 0x%02x, 0x%02x ; (cont) l=$len\n",
		    $cmd{'CONT'}, ($cnt & 0xff00) >> 8, ($cnt & 0xff);
	    }
	} else {
	    print_error($c, "unknown command");
	}

    } continue {
	$i++;
	if ($i > $#mml) {
	    last;
	}
    }
}
close(MML);

if (@data > 0) {
    print_data($ch, \@data);
} else {
    $ch--;
}
for (my $i = $ch + 1; $i < $maxch; $i++) {
    @data = (0xff);
    print_data($i, \@data);
}

sub print_data {
    my ($ch, $aref) = @_;
    my @data = @{$aref};

    print "MUSICDATA_CH$ch:\n";

    push(@data, 0xff);
    if ((@data % 2) == 1) {
	push(@data, 0xff);
    }

    my $n = 0;
    foreach my $i (@data) {
	if (($n % 8) == 0) {
	    print ".db\t";
	}
	printf "0x%02x", $i;
	$n++;
	if ($n < @data) {
	    if (($n % 8) == 0) {
		print "\n";
	    } else {
		print ", ";
	    }
	}
    }
    print "\n";
}

sub noteNumber {
    my ($o, $n) = @_;    # $n: "A", "E" (, "A+", "C-") etc.
    my ($nname, @nacc) = split(//, $n);

    # 1) C -> 0, D -> 1, ... , B -> 6
    my $nn = ord($nname) - ord("A");
    $nn -= 2;
    if ($nn < 0) {
	$nn += 7;
    }
    # 2) C -> 0, D -> 2, E -> 4, F -> 5, ...
    $nn *= 2;
    if ($nn > 5) {
	$nn--;
    }

    # NOT USED
    # 3) +/-
    foreach my $s (@nacc) {
	if (($s eq "+") || ($s eq "#")) {
	    $nn++;
	}
	if ($s eq "-") {
	    $nn--;
	}
    }

    return 12 * ($o - 1) + $nn;
}

sub noteLength {
    my ($T, $l) = @_;

    # Note:
    # my $len_Semibreve = 4 * 60 / $T;	# in second
    # my $len = $len_Semibreve / $l;	# in second
    # my $tick = 256 / $fCPU;		# time for 1 loop of 8 bit counter
    # my $cnt = $len / $tick;

    my $cnt = $cntdiff + 4 * 60 * $fCPU / (256 * $T * $l);

    my $ret = int($cnt + 0.5);
    $cntdiff = $cnt - $ret;

    return $ret
}

sub print_error {
    my ($c, $str) = @_;
    printf STDERR "Error:[%s]:0x%02x: $str\n", $c, ord($c), $str;
}
