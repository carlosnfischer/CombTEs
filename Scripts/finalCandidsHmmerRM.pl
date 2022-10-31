# Developed by Carlos Fischer - 20 Oct 2020
# Updated: 02 Aug 2022

# To generate the final candidates for HMMER and RepeatMasker, for all TE types.
# It generates also a separate file with the (initial) candidates for each TE type for each tool.

# If a sequence (whole or short) has no predictions with metrics (e-value or SWscore) with value equal or below/higher than the threshold ("$filterTOOL") for the respective TOOL, the ID of that sequence will not be shown in the output files.

####
# Usage: perl finalCandidsHmmerRM.pl TOOL
# This script would be launched by CombTEs.pl
####


# The script verifies, for each tool, if there is overlap between CANDIDATES from different TE types; for this, it calculates (using the "$maxPercCandidOutOverlap" percentage) the maximum size ("$maxSizeOutOverlap") of the smallest candidate allowed for the region outside the overlapping region to consider that there is an overlap between 2 CANDIDATES - in this case, the best predicted candidate (based on the lowest E-value or the highest SW score) defines the TE type classification for such a region (the "final candidate"), for each tool.

# The input file can be generated by the "extractHmmerRM.pl" script, which extracts and formats the predictions from the original output file of HMMER and RepeatMasker. Such a script names its output file as "TEtype_TOOL.pred" (like "Bel_HMMER.pred" and "Copia_RepeatMasker.pred"); this is the name used here in "finalCandidsHmmerRM.pl".


# This script uses 9 parameters:
# - 2 of them can be changed in "ParamsGeneral.pm":
#	- @TEtypes: the used TE types;
#	- %filterTools: thresholds for the candidates' e-values/SW scores for HMMER/RepeatMasker. 

# - 7 others can be changed in "ParamsHmmerRM.pm":
#   1 is a common parameter for both tools:
#	- $maxPercCandidOutOverlap: maximum percentage of the smallest CANDIDATE allowed to be outside the overlapping region to 		consider that there is an overlap between 2 CANDIDATES (default = 0.50 = 50% - a lower value would increase the number of 		CANDIDATES for a tool);
#   2 parameters used only by HMMER:
#	- $distPredsHMMER: maximum distance between 2 predictions to consider them inside the SAME candidate (default = 300);
#	- $minLenPredHMMER: minimum length for a HMMER's prediction to be included in the analyses (default = 20);
#   4 others used only by RepeatMasker:
#	- $distPredsRepeatMasker: maximum distance between 2 predictions to consider them inside the SAME candidate (default = 300);
#	- $minLenPredRepeatMasker: minimum length for a RepeatMasker's prediction to be included in the analyses (default = 20);
#	- $pattLtrs: the patterns used in Repbase database to describe a sequence as a specific LTR one (default = "-LTR|_LTR");
#	- $includeLTRs: to consider ("yes") or not ("no") LTR predictions in the analyses (default = "no").

###########################################################################################

use strict;
use warnings;

use Cwd qw(getcwd);
use lib getcwd(); 

use ParamsGeneral qw(@TEtypes %filterTools);
use ParamsHmmerRM qw($maxPercCandidOutOverlap $distPredsHMMER $distPredsRepeatMasker $minLenPredHMMER $minLenPredRepeatMasker $pattLtrs $includeLTRs);

my $filterHMMER        = $filterTools{'HMMER'};
my $filterRepeatMasker = $filterTools{'RepeatMasker'};
# DO NOT CHANGE the values of "$filterHMMER" and "$filterRepeatMasker" directly here; change them in "%filterTools" in "ParamsGeneral.pm" package.

###########################################################################################

sub verifyOverlap { # to verify overlap between 2 CANDIDATES and, if so, retrieve the ID of the ONE TO BE DISREGARDED; this candidate would be:
# - for HMMER:        the one with the highest e-value or, for the same e-values, the shortest candidate
# - for RepeatMasker: the one with the lowest SWscore  or, for the same SWscores, the shortest candidate.

    (my $method, my $seq1, my $seq2) = @_;

    my ($from1, $to1, $length1, $evalSWs1, $sense1);
    my ($from2, $to2, $length2, $evalSWs2, $sense2);

# For HMMER:
# $seq= Candidate_1 - FROM: ff - TO: tt - LENGTH: ll - EVALUE: ev - SENSE: dr - CLASSIFICATION: tetype\nPREDIC---FROM-- etc.
# For RepeatMasker:
# $seq= Candidate_1 - FROM: ff - TO: tt - LENGTH: ll - RMSCORE: s - SENSE: dr - CLASSIFICATION: tetype\nPREDIC---FROM-- etc.
    if (
	($seq1 =~ /FROM: (\d+) - TO: (\d+) - LENGTH: (\d+) - (EVALUE|RMSCORE): (.*) - SENSE: (.*) - CLASSIFICATION/)
       ) {
	$from1    = $1;
	$to1      = $2;
	$length1  = $3;
	$evalSWs1 = $5;
	$sense1   = $6;
    }
    if (
	($seq2 =~ /FROM: (\d+) - TO: (\d+) - LENGTH: (\d+) - (EVALUE|RMSCORE): (.*) - SENSE: (.*) - CLASSIFICATION/)
       ) {
	$from2    = $1;
	$to2      = $2;
	$length2  = $3;
	$evalSWs2 = $5;
	$sense2   = $6;
    }

    my $respOverl = "NONE"; # initially, it considers that there is NOT overlap between seq_1 and seq_2; otherwise, it retrieves the ID of the candidate to be disregarded
    if ($sense1 eq $sense2) {
	my $hasOverlap = "no";
#     testing if the candidates are apart from each other
	if ( ($to1 > $from2) and ($to2 > $from1) ) {
#	  calculating the maximum size ("$maxSizeOutOverlap" - according to the length of the smallest candidate) outside the 		  overlapping region to consider that there is an overlap between 2 candidates:
	    my $smallestLeng = $length1;
	    if ($length2 < $length1) { $smallestLeng = $length2; }
	    my $maxSizeOutOverlap = $maxPercCandidOutOverlap * $smallestLeng;

#	  IF: (seq_2 inside seq_1) OR (seq_1 inside seq_2) --->> overlap between predictions
	    if ( ( ($from1 <= $from2) and ($to2 <= $to1) ) or ( ($from2 <= $from1) and ($to1 <= $to2) ) ) { $hasOverlap = "yes"; }
#	  testing the maximum allowed region outside the overlap
	    elsif ( (abs($from1-$from2) <= $maxSizeOutOverlap) or (abs($to1-$to2) <= $maxSizeOutOverlap) )
	        # --->> if so, overlap between predictions
		  { $hasOverlap = "yes"; }
	} # IF ( ($to1 > $from2) and ($to2 > $from1) )

	if ($hasOverlap eq "yes") { # there is overlap between seq_1 and seq_2
	    if ($method eq "HMMER") {
		if    ($evalSWs1 < $evalSWs2) { $respOverl = "JJ"; }
		elsif ($evalSWs1 > $evalSWs2) { $respOverl = "II"; }
		else {
		    if ($length1 >= $length2) { $respOverl = "JJ"; }	
		    else		      { $respOverl = "II"; }
		}
	    }
	    elsif ($method eq "RepeatMasker") {
		if    ($evalSWs1 > $evalSWs2) { $respOverl = "JJ"; }
		elsif ($evalSWs1 < $evalSWs2) { $respOverl = "II"; }
		else {
		    if ($length1 >= $length2) { $respOverl = "JJ"; }	
		    else		      { $respOverl = "II"; }
		}
	    }
	} # IF ($hasOverlap eq "yes")
    } # IF ($sense1 eq $sense2)

    return ($respOverl, $sense1, $sense2);
} # END of SUB "verifyOverlap"

###########################################################################################


my $tool = $ARGV[0];

my ($metrics, $maxDistPreds);
if ($tool eq "HMMER") {
	$metrics = "EVALUE";
	$maxDistPreds = $distPredsHMMER;
}
elsif ($tool eq "RepeatMasker") {
	$metrics = "RMSCORE";
	$maxDistPreds = $distPredsRepeatMasker;
}

my @candidAllTEtype; # for ALL candidates (of ALL TE types) from each tool for FINAL classification

my @seqNames; # for the IDs of the sequences with at least one candidate
my %hashTEtype = ();

foreach my $TEtype (@TEtypes) {
    my $inPred = "$TEtype\_$tool";

    my $predFile = "$inPred.pred"; # file with predictions of each TE type from each tool
    open (PREDFILE, $predFile) or die "\nCan't open $predFile!!!\n\n";
    my @linesIN = <PREDFILE>;
    close (PREDFILE);

    my $qttLinesIN = scalar(@linesIN);

    my $tetypeCandids = "$inPred-candidates.pred"; # for the candidates of each **TE type** (for each tool)
    open (TETYPECANDIDS, ">$tetypeCandids") or die "\nCan't open $tetypeCandids!!!\n\n";
    print TETYPECANDIDS "Candidates of $tool for \*$TEtype\*, from file \"$predFile\".\n";
    print TETYPECANDIDS "Maximum distance between two predictions to consider them inside the same candidate: $maxDistPreds.\n";
    if ($tool eq "HMMER") { print TETYPECANDIDS "Thresholds for E-value and length: $filterHMMER and $minLenPredHMMER nt.\n\n"; }
    elsif ($tool eq "RepeatMasker") { print TETYPECANDIDS "Thresholds for SWscore and length: $filterRepeatMasker and $minLenPredRepeatMasker nt.\n\n"; }

    my $toolCandids = "finalCandidates_$tool.txt";  # for the FINAL candidates of each **tool**	
    open (TOOLCANDIDS, ">$toolCandids") or die "\nCan't open $toolCandids!!!\n\n";
    print TOOLCANDIDS "Final candidates of $tool, with the predictions used to generate each one.\n";
    print TOOLCANDIDS "Maximum distance between two predictions to consider them inside the same candidate: $maxDistPreds.\n";
    if    ($tool eq "HMMER")  { print TOOLCANDIDS "Threshold for E-value and minimum length: $filterHMMER and $minLenPredHMMER nt.\n\n"; }
    elsif ($tool eq "RepeatMasker") { print TOOLCANDIDS "Threshold for SWscore and minimum length: $filterRepeatMasker and $minLenPredRepeatMasker nt.\n\n"; }


    my $numCandid;
    my $i = 0;
    my ($newCandid, $startCandid, $endCandid, $senseCandid, $evalSwsCand, $typeCandid, @candidTEtype, @arrayToPrint);

    while ($i < $qttLinesIN) {
	my $line = $linesIN[$i]; chomp $line;

	if ($line =~ />>>SEQUENCE/) {
		push (@arrayToPrint, $line);
		$newCandid = "yes";
		@candidTEtype = ();
		$numCandid = 0;
		$i++;
	} # IF ($line =~ />>>SEQUENCE/)
# from an input file:
# from HMMER:	PREDIC---FROM--ff---TO--tt---LENGTH--ll---EVALUE--ev---SCORE--sc---SENSE--d/r---TETYPE--type
# from RM:	PREDIC---FROM--ff---TO--tt---LENGTH--ll---RMSCORE--sc---SENSE--dr---MATCHINGREPEAT--match---TETYPE--type
	elsif ($line =~ /FROM--(\d+)---TO--(\d+)---LENGTH--(\d+)---(EVALUE|RMSCORE)/) {
	    my $from     = $1;
	    my $to       = $2;
	    my $lengPred = $3;

	    my $OKfilter = "no";
	    my ($evalSws, $sense);

## generating candidates of EACH **TE type** (for each tool)
### filtering predictions based on the e-values for HMMER OR SWscores for RepeatMasker, AND based on the lengths for both tools
	    if ($line =~ /EVALUE--(.*)---SCORE--.*---SENSE--(.*)---TETYPE/) {
		$evalSws = $1;
		$sense   = $2;
		if ( ($evalSws <= $filterHMMER) and ($lengPred >= $minLenPredHMMER) ) { $OKfilter = "yes"; }
	    }
	    elsif ($line =~ /RMSCORE--(\d+)---SENSE--(.*)---MATCHINGREPEAT--(.*)---TETYPE/) {
		$evalSws  = $1;
		$sense    = $2;
		my $matchRep = $3;
		if ( ($evalSws >= $filterRepeatMasker) and ($lengPred >= $minLenPredRepeatMasker) ) {
		    if ( ($includeLTRs eq "yes") or ($matchRep !~ /$pattLtrs/) ) { $OKfilter = "yes"; }
		}
	    }

	    if ($OKfilter eq "yes") {
		if ($newCandid eq "yes") {
			$startCandid  = $from;
			$endCandid    = $to;
			$evalSwsCand  = $evalSws;
			$senseCandid  = $sense;
			@candidTEtype = ();
			push (@candidTEtype, $line);
			$newCandid = "no";
			$i++;
		}
		else { # ($newCandid eq "no") (it is the same candidate)
			if ( ($sense eq $senseCandid) and (($from - $endCandid) <= $maxDistPreds) ) {
			# it will be a new candidate only if: "different senses" OR "dist(from-endCandid) > maxDistPreds"
				if ($to > $endCandid) { $endCandid = $to; }
				if    ($tool eq "HMMER")	{ if ($evalSws < $evalSwsCand) { $evalSwsCand = $evalSws; } }
				elsif ($tool eq "RepeatMasker")	{ if ($evalSws > $evalSwsCand) { $evalSwsCand = $evalSws; } }
				push (@candidTEtype, $line);
				$i++;
			}
			else { $newCandid = "yes"; } # found a new candidate: write the current one
		} # ELSE { # $newCandid eq "no"
	    } # IF ($OKfilter eq "yes")
	    else { $i++; }

	    if ( ($newCandid eq "yes") or ($i == $qttLinesIN) or ($linesIN[$i] eq "###\n") ) {
	    # it is a NEW candidate OR end of the current sequence: save the current candidate
		my $qttInCandid = scalar(@candidTEtype);
		if ($qttInCandid != 0) {
			$numCandid++;
			my $lengthCandid = $endCandid - $startCandid + 1;
			my $idCandid = "Candidate_$numCandid - FROM: $startCandid - TO: $endCandid - LENGTH: $lengthCandid - $metrics: $evalSwsCand - SENSE: $senseCandid - CLASSIFICATION: $TEtype";
#		    to save the candidates to a file for EACH TE type (for each tool)
			push (@arrayToPrint, $idCandid);
			for (my $j = 0; $j < $qttInCandid; $j++) { push (@arrayToPrint, $candidTEtype[$j]); }
			$newCandid = "yes";
		} # IF ($qttInCandid != 0)
	    } # IF ( ($newCandid eq "yes") or ...
## here, "@arrayToPrint" has: (a) ">>>SEQUENCE" and (b) one or more "$idCandid" and its related "PREDIC" (one or more "PREDIC")
	} # ELSIF ($line =~ /FROM ...
	elsif ($line eq "###") {
		my $qttToPrint = scalar(@arrayToPrint);
		if ($qttToPrint > 1) {
			my $candidPrint = "";
			my $idSeqHash;
			foreach my $lineCand (@arrayToPrint) {
				if ($lineCand =~ />>>SEQUENCE: (.*)/) {
					$idSeqHash = $1;
					push (@seqNames, $idSeqHash);
					$hashTEtype{$TEtype}{$idSeqHash} = "";
				}
				elsif ($lineCand =~ /Candidate_(\d+) - FROM/) {
					if ($1 != 1) {
						print TETYPECANDIDS "\n";
						$hashTEtype{$TEtype}{$idSeqHash} .= "###";
					}
					$hashTEtype{$TEtype}{$idSeqHash} .= "$lineCand";
				}
				elsif ($lineCand =~ /PREDIC/) { 
					$hashTEtype{$TEtype}{$idSeqHash} .= "\n$lineCand";
				}
				print TETYPECANDIDS "$lineCand\n";
			} # FOREACH my $lineCand (@arrayToPrint)
			print TETYPECANDIDS "###\n\n";
		} # IF ($qttToPrint > 1)
		@arrayToPrint = ();
		$i++;
	} # ELSIF ($line eq "###")
	else { $i++; }
    } # WHILE ($i < $qttLinesIN)
## END of generating candidates of each **TE type** (for each tool)

    close (TETYPECANDIDS);
} # FOREACH my $TEtype (@TEtypes)

## Generating the FINAL CANDIDATES for all TE types TOGETHER for EACH TOOL:
my %uniqueHash = ();
foreach my $name (@seqNames) { $uniqueHash{$name} ++; }
my @uniqueSeqNames = keys %uniqueHash;

foreach my $idUnique (@uniqueSeqNames) {
    my @candidAllTEfinal; # for ALL candidates (of ALL TE types) from each tool for FINAL classification
    foreach my $TEtype (@TEtypes) {
	if ( exists ($hashTEtype{$TEtype}{$idUnique}) ) {
	    my @arraySplit = split '###', $hashTEtype{$TEtype}{$idUnique};
	    my $qttSplit = scalar(@arraySplit);
	    for (my $j = 0; $j < $qttSplit; $j++) {
		my $lineCand = $arraySplit[$j];
		if ($lineCand =~ /Candidate_\d+ - FROM: (\d+) - TO/) {
			my $startCandid = $1;
			push (@candidAllTEfinal, {line => $lineCand, from => $startCandid} );
		}
	    }
	} # IF ( exists ($hashTEtype{$TEtype}{$idUnique}) )
    } # FOREACH my $TEtype (@TEtypes)

    my $qttCandidAllTEfinal = scalar(@candidAllTEfinal);
    if ($qttCandidAllTEfinal != 0) {
	print TOOLCANDIDS ">>>SEQUENCE: $idUnique\n";
	print ">>>SEQUENCE: $idUnique\n"; # output to CombTEs
	my @auxSorted = sort{ $a->{from} <=> $b->{from} } @candidAllTEfinal;
	my @sortedCandidAllTEtype = ();
	foreach my $lineAux (@auxSorted) { push (@sortedCandidAllTEtype, $lineAux->{line}); }

## Verifying possible overlap between 2 CANDIDATES:
	my $qttCandid = scalar(@sortedCandidAllTEtype);
	for (my $i = 0; $i < $qttCandid-1; $i++) {
   	    for (my $j = $i+1; $j < $qttCandid; $j++) {
		if ($sortedCandidAllTEtype[$i] =~ /-->OUT/) { last; }
		else {
		    my ($resp, $sense1, $sense2) = verifyOverlap ($tool, $sortedCandidAllTEtype[$i], $sortedCandidAllTEtype[$j]);
		    if    ($resp eq "II") { $sortedCandidAllTEtype[$i] .= "-->OUT"; }
		    elsif ($resp eq "JJ") { $sortedCandidAllTEtype[$j] .= "-->OUT"; }
		    elsif ($sense1 eq $sense2) { last; }
		}
	    }
	}

## Writing the CANDIDATES:
	my $numCandid = 0;
	for (my $i = 0; $i < $qttCandid; $i++) {
	    my $candidCurrent = $sortedCandidAllTEtype[$i];
	    if ($candidCurrent !~ /-->OUT/) {
		if ($numCandid != 0) { print TOOLCANDIDS "\n"; }
		$numCandid++;
# for HMMER: Candidate_num - FROM: ff - TO: tt - LENGTH: ll - EVALUE: ev - SENSE: d/r - CLASSIFICATION: type 
# for RM:    Candidate_num - FROM: ff - TO: tt - LENGTH: ll - RMSCORE: sc - SENSE: d/r - CLASSIFICATION: type
		if ($candidCurrent =~ /Candidate_\d+ - (.*)- $metrics: .* - SENSE: (.*)/) {
		    my $idCandid = "CANDIDATE_$numCandid - $1- SENSE: $2";
		    print TOOLCANDIDS "$idCandid\n";
		    print "$idCandid\n";  # output to CombTEs

#		    write the predictions used to generate the candidate
		    my @arraySplit = split '\n',$candidCurrent;
		    my $qttSepara = scalar(@arraySplit);
		    for (my $j = 1; $j < $qttSepara; $j++) {
			print TOOLCANDIDS "$arraySplit[$j]\n";
			print "$arraySplit[$j]\n";  # output to CombTEs
		    }
		} # IF ($candidCurrent =~ ...
	    } # IF ($candidCurrent !~ /-->OUT/)
	} # FOR (my $i = 0; $i < $qttCandid; $i++)
	print TOOLCANDIDS "###\n\n";
	print "###\n"; # output to CombTEs
    } # IF ($qttCandidAllTEfinal != 0)

} # FOREACH my $idUnique (@uniqueSeqNames)

close (TOOLCANDIDS);

