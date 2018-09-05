#!/usr/bin/env perl
$|=1;

use strict;
use warnings;
use Getopt::Std;
use File::Basename;
use Benchmark;
use Cwd;
use FindBin '$Bin';
use lib "$Bin/lib";
use lib "$Bin/lib/bioperl-1.5.2_102/";
use marfil_homology;

my (%opts,$INP_dir,$INP_bpofile,$INP_taxon,$INP_evalue,$INP_overlap,$INP_besthit,$INP_forceredo);

getopts('hH:d:b:t:E:C:f:', \%opts);

if(($opts{'h'})||(scalar(keys(%opts))==0))
{
  print   "\nusage: $0 [options]\n\n";
  print   "-h this message\n";
  print   "-d directory with input files\n";
  print   "-b .bpo file generated by sub blast_parse (marfil_homology.pm)\n";
  print   "-t taxon name\n";
  print   "-E max E-value\n";
  print   "-C min \%coverage in BLAST pairwise alignments\n";
  print   "-H cluster non-overlapping isoforms sharing best hit\n";
  print   "-f force recalculation, otherwise might recover previous results\n\n";
  exit(0);
}

if(defined($opts{'d'})){  $INP_dir = $opts{'d'}; }
else{ die "# EXIT : need a -d directory\n"; }

if(defined($opts{'b'})){  $INP_bpofile = $opts{'b'}; }
else{ die "# EXIT : need a -b bpofile as input\n"; }

if(defined($opts{'t'})){  $INP_taxon = $opts{'t'}; }
else{ die "# EXIT : need parameter -t\n"; }

if(defined($opts{'E'})){  $INP_evalue = $opts{'E'}; }
else{ die "# EXIT : need parameter -E\n"; }

if(defined($opts{'C'})){ $INP_overlap = $opts{'C'}; }
else{ die "# EXIT : need parameter -C\n"; }

if(defined($opts{'H'})){ $INP_besthit = $opts{'H'}; }
else{ die "# EXIT : need parameter -H\n"; }

if(defined($opts{'f'})){ $INP_forceredo = $opts{'f'}; }
else{ die "# EXIT : need parameter -f\n"; }

##########################################################################

## 1) create required data structures and get right file/dir names
constructDirectory($INP_dir);
$bpo_file = $INP_bpofile;
construct_taxa_indexes($bpo_file);

# %gindex y %gindex2 are created here, while calling construct_indexes($bpo_file,($INP_taxon=>1))
my($rhash_inparalogues) = makeInparalog(1,$INP_taxon,$INP_evalue,$INP_overlap,$INP_besthit,$INP_forceredo);

