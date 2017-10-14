#!/usr/bin/env bash

# 2015-7 Pablo Vinuesa (1) and Bruno Contreras-Moreira (2):
# 1: http://www.ccg.unam.mx/~vinuesa (Center for Genomic Sciences, UNAM, Mexico)
# 2: http://www.eead.csic.es/compbio (Laboratory of Computational Biology, EEAD/CSIC, Spain)

#: AIM: Prints ordered matrix heatmap (without computing distance)
#       based on a tab-delimited input file with header and rownames
#: OUTPUT: svg and pdf; png not implemented yet

progname=${0##*/} # plot_matrix_heatmap.sh
VERSION='v0.6_14Oct17'   # added options -X (charExp) and -a (label rotation angle)
         #'v0.5_18Aug17' # added options -d (max no. decimals) and -x (filter matrix with regex)
         #'v0.4_17Aug17' # added option -r to remove column names and cell contents, and -k 
         #'v0.3_13Apr16' # added option -c to filter input matrix by a maximum similarity cut-off value
                         # to reduce excessive redundancy. Improved the help text printed with -M
         #'0.2_26Feb15'  # wrote R function sim2dist() to compute bioNJ tree with ape
                         # based on ANI sim-matrix, and write it to file as newick string
         #'0.1_16Feb15'; first version

date_F=$(date +%F |sed 's/-/_/g')-
date_T=$(date +%T |sed 's/:/./g')
start_time="$date_F$date_T"

#---------------------------------------------------------------------------------#
#>>>>>>>>>>>>>>>>>>>>>>>>>>>> FUNCTION DEFINITIONS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#
#---------------------------------------------------------------------------------#

function print_help()
{
    cat << HELP
    
    USAGE synopsis for: [$progname v.$VERSION]:
       $progname <string (tab-delimited matrix file)> [-t|-m|-v|-o|-p|-H|-W|-C|-r|-k|-N|-M]
    
    REQUIRED
       -i <string> presence_absence tab file     
       
    OPTIONAL:
     I) filter out excessive redundancy in the tab-delimited ANI matrix file
       -c <float> (maximum) identity cut-off value (e.g. 97.3) [def: $sim_cutoff]
       -d <int> maximum number of decimals in matrix display [0-2; def: $decimals]
	
    II) tweak the graphical output:
       -a <integer> angle to rotate node angles           [def $angle]
       -t <string> text for plot title                    [def input_tab_file_name]
       -m <integer> margins_horizontal                    [def $margin_hor]
       -v <integer> margins_vertical                      [def $margin_vert] 
       -o <string> output file format                     [def $outformat]
       -p <integer> points for plotting device            [def $points]    
       -H <integer> output device height                  [def $height]    
       -W <integer> output device width                   [def $width]     
       -C <flag> do not reorder clusters                  [def reorder clusters and plot dendrogram]
       -r <flag> remove column names and cell contents    [def names and cell contents are printed]
       -k <string> text for scale X-axis                  [def "Value"]
       -X <float> character expansion factor              [def $charExp]
    
    RUN NJ ANALYSIS using ANI matrix (average identity matrix) generated by get_homologues.pl -A -t 0 -M|G
       -N <flag> will compute a distance matrix from the input similarity matrix
                 and use the former to construct a NJ tree and save it as newick string
		 Do not use with a binary presence-absence matrix
    
    SUBSET MATRIX WITH REGULAR EXPRESSIONS
       -x <string> regex, like: 'Smalt|Smc'               [def $regex]
    
    MORE DETAILED HELP:
       -M <flag> prints gplot installation instructions and further usage information
       
    EXAMPLE:
      $progname -i Avg_identity.tab -c 98 -t "Genus X ANIb (OMCL all clusters)" -N -o pdf -m 22 -v 22 -p 20 -H 20 -W 30 -x 'Smalt|Smc' -d 1 -a 45 -X 0.9

    #------------------------------------------------------------------------------------------------------------------
    AIM: Plot ordered heatmaps with row and col. dendrogram, from squared numeric (distance or presence-absence) matrix,
         like the *Avg_identity.tab matrices produced by get_homologues.pl with the -A flag
          
    OUTPUT:  svg|pdf files
    
    DEPENDENCIES:
         R packages ape and gplots. Run $progname -M for installation instructions.
    
    NOTES: 
      1. To improve the display, shorten the genome/taxon names as much as possible
      2. Use -m and -v to control horizontal and vertial margins to the plot
         to fit the taxon labels
    #------------------------------------------------------------------------------------------------------------------
 
HELP

    check_dependencies
    
exit 0

}
#--------------------------------------------------------------------------------------

function print_man()
{
    cat << MAN
    
    $progname is a simple shell wrapper around heatmap.2() from the gplots pacakge.
    Generates ordered heatmaps with row and column dendrograms from
    an input distace/dissimilarity matrix, or a binary presence-abasence matrix.
    
    1) If the package is not installed on your system, then proceed as follows:
    
    i) with root privileges, type the following into your shell console:
       sudo R
       > install.packages(c("gplots", "ape"), dependencies=TRUE)
       > q()
       
       $ exit # exit from the root account
       $ R    # call R
       > library("gplots") # load the lib; do your stuff
       > library("ape") # load the lib; do your stuff
       
    ii) without root privileges, intall the package into ~/lib/R as follows:
       $ mkdir -p ~/lib/R
       
       # set the R_LIBS environment variable before starting R as follows:
       $ export R_LIBS=~/lib/R     # bash syntax
       $ setenv R_LIBS=~/lib/R     # csh syntax
       # You can type the corresponding line into your .bashrc (or similar) configuration file
       # to make this options persistent
       
       # Call R from your terminal and type:
       > install.packages("gplots", dependencies=TRUE, lib="~/lib/R") 	
   
   2) Once installed, you can read the documentation for packages and functions by typing the following into the R console:
      library("gplots")       # loads the lib into the environment
      library("ape")
      help(package="gplots")  # read about the gplots package
      help(heatmap.2)         # read about the heatmap.2 function      
      help(svg)               # read about the svg function, which generates the svg ouput file     
      help(pdf)               # read about the pdf function, which generates the pdf ouput file     
       ...
       
MAN

exit 0

}
#--------------------------------------------------------------------------------------

function check_dependencies()
{
    for prog in R
    do 
       bin=$(type -P $prog)
       if [ -z $bin ]; then
          echo
          echo "# ERROR: $prog not in place!"
          echo "# ... you will need to install \"$prog\" first or include it in \$PATH"
          echo "# ... exiting"
          exit 1
       fi
    done

    echo
    echo '# Run check_dependencies() ... looks good: R is installed.'
    echo   
}

#---------------------------------------------------------------------------------------#
#----------------------------------- GET OPTIONS ---------------------------------------#
#---------------------------------------------------------------------------------------#
tab_file=
regex=

check_dep=0

sim_cutoff=100

text=
width=15
height=10
points=15
margin_hor=18
margin_vert=18
outformat=svg
do_nj=0
reorder_clusters=1
remove_colnames=0
key_xaxis="Value"
decimals=0
charExp=1.0
angle=45

subset_matrix=0

# See bash cookbook 13.1 and 13.2
while getopts ':a:c:i:d:t:m:o:p:v:x:X:H:W:k:hrMNC?:' OPTIONS
do
   case $OPTIONS in

   a)   angle=$OPTARG
        ;;
   c)   sim_cutoff=$OPTARG
        ;;
   d)   decimals=$OPTARG
        ;;
   i)   tab_file=$OPTARG
        ;;
   m)   margin_hor=$OPTARG
        ;;	
   v)   margin_vert=$OPTARG
        ;;
   o)   outformat=$OPTARG
        ;;
   p)   points=$OPTARG
        ;;
   t)   text=$OPTARG
        ;;
   H)   height=$OPTARG
        ;;
   W)   width=$OPTARG
        ;;
   M)   print_man && exit 0
        ;;
   N)   do_nj=1
        ;;
   r)   remove_colnames=1
        ;;
   k)   key_xaxis=$OPTARG
        ;;
   x)   regex=$OPTARG
        ;;
   X)   charExp=$OPTARG
        ;;
   C)   reorder_clusters=0
        ;;
   \:)   printf "argument missing from -%s option\n" $OPTARG
   	 print_help
     	 exit 2 
     	 ;;
   \?)   echo "need the following args: "
   	 print_help
         exit 3
	 ;;
    *)   echo "An  unexpected parsing error occurred"
         echo
         print_help
	 exit 4
	 ;;	 
   esac >&2   # print the ERROR MESSAGES to STDERR
done

shift $(($OPTIND - 1))

if [ -z $tab_file ]
then
    echo "# ERROR: no input tab file defined!"
    print_help
    exit 1    
fi

if [ -z "$text" ]
then
    text=$(echo $tab_file)
fi

if [ ! -z "$regex" ]
then
    subset_matrix=1
fi


#-------------------#
#>>>>>> MAIN <<<<<<<#
#-------------------#

# 0) print run's parameter setup
wkdir=$(pwd)

cat << PARAMS

##############################################################################################
>>> $progname v$VERSION run started at $start_time
        working directory = $wkdir
        input tab_file = $tab_file | sim_cutoff = $sim_cutoff | max_decimals = $decimals
	subset_matrix = $subset_matrix | regex = $regex
        text=$text|margin_hor=$margin_hor|margin_vert=$margin_vert|points=$points
	angle=$angle|charExp=$charExp
        width=$width|height=$height|outformat=$outformat
        reorder_clusters=$reorder_clusters|remove_colnames=$remove_colnames|key_xaxis=$key_xaxis|do_bioNJ=$do_nj
        
##############################################################################################

PARAMS

# 1) prepare R's output file names
sim_cutoff_int=$(echo $sim_cutoff | cut -d\. -f1)
if [ $sim_cutoff_int -ne 100 ]
then
   heatmap_outfile="${tab_file%.*}_sim_cutoff_${sim_cutoff}_heatmap.$outformat"
   echo "# Plotting file $heatmap_outfile"
   nj_tree="${tab_file%.*}_sim_cutoff_${sim_cutoff}_BioNJ.ph"
else
   heatmap_outfile="${tab_file%.*}_heatmap.$outformat"
   echo "# Plotting file $heatmap_outfile"
   nj_tree="${tab_file%.*}_BioNJ.ph"
fi

# 2) call R using a heredoc and write the resulting script to file 
R --no-save -q <<RCMD > ${progname%.*}_script_run_at_${start_time}.R
library("gplots")
library("ape")
options(expressions = 100000) #https://stat.ethz.ch/pipermail/r-help/2004-January/044109.html
tab <- read.table(file="$tab_file", header=TRUE)
mat_dat <- data.matrix(tab[,2:ncol(tab)])

mat_dat <- round(mat_dat,$decimals)

rnames <- tab[,1]
rownames(mat_dat) <- rnames

if($subset_matrix > 0 ){
  include_list <- grep("$regex", rownames(mat_dat))
   mat_dat <- mat_dat[include_list, ]
   mat_dat <- mat_dat[,include_list]
}

if($sim_cutoff < 100)
{
   tmp_mat = mat_dat
   diag(tmp_mat) = NA
   rows <- (!apply( tmp_mat , 1 , function(x) any( x > $sim_cutoff , na.rm=T) ) )
   mat_dat <- mat_dat[rows, rows]
}

if($reorder_clusters > 0){
  if($remove_colnames > 0){
    $outformat("$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)  
    heatmap.2(mat_dat, main="$text", notecol="black", density.info="none", key.xlab="$key_xaxis",
      trace="none", margins=c($margin_vert,$margin_hor), lhei = c(1,5), labCol=F,
      cexRow=$charExp, cexCol=$charExp, srtRow=$angle, srtCol=$angle)
    dev.off()
  }
  else {
    $outformat("$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)  
    heatmap.2(mat_dat, cellnote=mat_dat, main="$text", notecol="black", density.info="none", key.xlab="$key_xaxis",
      trace="none", margins=c($margin_vert,$margin_hor), lhei = c(1,5), 
      cexRow=$charExp, cexCol=$charExp, srtRow=$angle, srtCol=$angle)
    dev.off()
  }
} else {
  if($remove_colnames > 0){
    $outformat("$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)  
    heatmap.2(mat_dat, main="$text", notecol="black", density.info="none", labCol=F, key.xlab="$key_xaxis",
    trace="none", margins=c($margin_vert,$margin_hor), lhei = c(1,5), dendrogram = "row", Colv = FALSE, 
    cexRow=$charExp, cexCol=$charExp, srtRow=$angle, srtCol=$angle)
    dev.off()
  }
  else {
    $outformat("$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)  
    heatmap.2(mat_dat, cellnote=mat_dat, main="$text", notecol="black", density.info="none", key.xlab="$key_xaxis",
    trace="none", margins=c($margin_vert,$margin_hor), lhei = c(1,5), dendrogram = "row", Colv = FALSE,
    cexRow=$charExp, cexCol=$charExp, srtRow=$angle, srtCol=$angle)
    dev.off()
  }
}  
if($do_nj > 0){
  sim2dist <- function(x) 100 - x
  bionj <- bionj(as.dist(apply(mat_dat, 1, sim2dist)))
  write.tree(phy=bionj, file="$nj_tree")
}
RCMD

if [ -s $heatmap_outfile ]
then
     echo ">>> file $heatmap_outfile was produced"
     echo
else
     echo ">>> ERROR: file $heatmap_outfile was NOT produced."
     echo
     echo ">>> You can try option -C or alternatively remove columns in the matrix."
     echo
fi

if [ $do_nj -eq 1 ] && [ -s $nj_tree ]
then
     echo ">>> file $nj_tree was produced"
     echo
fi

if [ $do_nj -eq 1 ] && [ ! -s $nj_tree ] 
then
     echo ">>> ERROR: file $nj_tree was NOT produced!"
     echo
fi
