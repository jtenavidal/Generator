#!/usr/bin/perl

#----------------------------------------------------------------------
# Submit jobs for calculating GENIE eA cross section splines to be used 
# with GENIE's validation programs comparing GENIE against electron 
# scattering data.
#
# Syntax:
#   shell% perl submit_eA_xsec_calc_jobs.pl <options>
#
# Options:
#    --version       : GENIE version number
#   [--arch]         : <SL4_32bit, SL5_64bit>, default: SL5_64bit
#   [--production]   : default: <version>
#   [--cycle]        : default: 01
#   [--use-valgrind] : default: off
#   [--batch-system] : <PBS, LSF>, default: PBS
#   [--queue]        : default: prod
#   [--softw-topdir] : default: /opt/ppd/t2k/softw/GENIE
#
# Notes:
#   * Use GENIE gspladd utility to merge the job outputs
#
# Tested at the RAL/PPD Tier2 PBS batch farm.
#
# Costas Andreopoulos <costas.andreopoulos \at stfc.ac.uk>
# STFC, Rutherford Appleton Lab
#----------------------------------------------------------------------

use File::Path;

# inputs
#  
$iarg=0;
foreach (@ARGV) {
  if($_ eq '--version')       { $genie_version = $ARGV[$iarg+1]; }
  if($_ eq '--arch')          { $arch          = $ARGV[$iarg+1]; }
  if($_ eq '--production')    { $production    = $ARGV[$iarg+1]; }
  if($_ eq '--cycle')         { $cycle         = $ARGV[$iarg+1]; }
  if($_ eq '--use-valgrind')  { $use_valgrind  = $ARGV[$iarg+1]; }
  if($_ eq '--batch-system')  { $batch_system  = $ARGV[$iarg+1]; }
  if($_ eq '--queue')         { $queue         = $ARGV[$iarg+1]; }
  if($_ eq '--softw-topdir')  { $softw_topdir  = $ARGV[$iarg+1]; }
  $iarg++;
}
die("** Aborting [Undefined GENIE version. Use the --version option]")
unless defined $genie_version;

$use_valgrind   = 0                          unless defined $use_valgrind;
$arch           = "SL5_64bit"                unless defined $arch;
$production     = "$genie_version"           unless defined $production;
$cycle          = "01"                       unless defined $cycle;
$batch_system   = "PBS"                      unless defined $batch_system;
$queue          = "prod"                     unless defined $queue;
$softw_topdir   = "/opt/ppd/t2k/softw/GENIE" unless defined $softw_topdir;
$genie_setup    = "$softw_topdir/builds/$arch/$genie_version-setup";
$jobs_dir       = "$softw_topdir/scratch/xsec\_eA-$production\_$cycle/";

$nkots     = 200;
$emax      =  35;
$probes    = "11";
%targets = (
	'H1'    =>  '1000010020',
	'H2'    =>  '1000010020',
	'H3'    =>  '1000010030',
	'He3'   =>  '1000020030',
	'He4'   =>  '1000020040',
	'C12'   =>  '1000060120',
	'N14'   =>  '1000070140', 
	'O16'   =>  '1000080160', 
	'Ne20'  =>  '1000100200', 
	'Al27'  =>  '1000130270', 
	'Ca40'  =>  '1000200400', 
	'Ca48'  =>  '1000200480', 
	'Fe56'  =>  '1000260560',
	'Kr83'  =>  '1000360830',
	'Xe131' =>  '1000541310',  
	'Au197' =>  '1000791970',  
	'Pb208' =>  '1000822080',  
	'U238'  =>  '1000922380'   );

# make the jobs directory
#
mkpath ($jobs_dir, {verbose => 1, mode=>0777});

#
# loop over nuclear targets & submit jobs
#
while( my ($tgt_name, $tgt_code) = each %targets ) {

    $fntemplate    = "$jobs_dir/job_$tgt_name";
    $grep_pipe     = "grep -B 100 -A 30 -i \"warn\\|error\\|fatal\"";
    $cmd  = "gmkspl -p $probes -t $tgt_code -n $nkots -e $emax -o gxspl_emode_$tgt_name.xml | $grep_pipe &> $fntemplate.mkspl.log";
    print "@@ exec: $cmd \n";

    # PBS case
    if($batch_system eq 'PBS') {
	$batch_script = "$fntemplate.pbs";
	open(PBS, ">$batch_script") or die("Can not create the PBS batch script");
	print PBS "#!/bin/bash \n";
        print PBS "#PBS -N $tgt_name \n";
        print PBS "#PBS -o $fntemplate.pbsout.log \n";
        print PBS "#PBS -e $fntemplate.pbserr.log \n";
	print PBS "source $genie_setup \n";
	print PBS "cd $jobs_dir \n";
	print PBS "export GEVGL=EM \n";
	print PBS "$cmd \n";
        close(PBS);
	`qsub -q $queue $batch_script`;
    } #PBS

    # LSF case
    if($batch_system eq 'LSF') {
	$batch_script = "$fntemplate.sh";
	open(LSF, ">$batch_script") or die("Can not create the LSF batch script");
	print LSF "#!/bin/bash \n";
        print LSF "#BSUB-j $tgt_name \n";
        print LSF "#BSUB-q $queue \n";
        print LSF "#BSUB-o $fntemplate.lsfout.log \n";
        print LSF "#BSUB-e $fntemplate.lsferr.log \n";
	print LSF "source $genie_setup \n";
	print LSF "cd $jobs_dir \n";
	print LSF "export GEVGL=EM \n";
	print LSF "$cmd \n";
        close(LSF);
	`bsub < $batch_script`;
    } #LSF

}

