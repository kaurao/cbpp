#! /usr/bin/env bash
# This script is a wrapper to run FC computation for HCP fMRI data in fsLR space.
# Jianxiao Wu, last edited on 12-Sept-2019

###########################################
# Define paths
###########################################

UTILITIES_DIR=$(dirname "$(dirname "$(readlink -f "$0")")")/utilities
BIN_DIR=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")/bin

###########################################
# Main commands
###########################################
main(){

# get total number of subjects to run
if [ -z $sub_id ]; then n_sub=`cat $sub_list | wc -l`; else; n_sub=1; fi

# loop through each subject
for i in {1..$n_sub}; do
  
  # get subject ID from subject-list file if not provided
  if [ -z $sub_id ]; then sub_id=`head -$i $sublist | tail -1`; fi

  # loop through each run
  for run in REST1_LR REST1_RL REST2_LR REST2_RL; do
    echo "Running sub$sub_id $run"
    out_prefix=HCP_${preproc}_parc${n_parc}_sub${sub_id}_${run}
    input=$input_dir/$out_prefix.mat

    if [ "$corr" == "Pearson" ]; then
      matlab -nodesktop -nosplash -r "load('$input', 'vol_parc'); \
                                      addpath('$UTILITIES_DIR'); \
                                      FC_Pearson(vol_parc, '$out_dir', '$out_prefix'); \
                                      exit"
    elif [ "$corr" == 'partial_l2' ]; then
      matlab -nodesktop -nosplash -r "load('$input', 'vol_parc'); \
                                      addpath('$BIN_DIR/external_packages/FSLNets'); \
                                      fc = nets_netmats(vol_parc', 1, 'ridgep'); \
                                      save(['$out_dir' '/' '$out_prefix' '_partial_l2.mat'], 'fc'); \
                                      exit"
    fi
  done
done

}

###########################################
# Function usage
###########################################

usage() { echo "
Usage: $0 -d <input_dir> -n <n_parc> -p <preproc> -c <corr> -s <sub_list> -i <sub_id> -o <output_dir>

This script is a wrapper to compute functional connectivity (FC) for HCP fMRI data in fsLR space, which
were previously parcellated using the Schaefer atlas. 

By default, all subjects in the specified sub_list are processed. For better parallelisation, use the 
-i option to specify one subject to run at a time.

REQUIRED ARGUMENT:
  -d <input_dir>  absolute path to input directory. The directory is assumed to be the output directory 
                  in step 1

OPTIONAL ARGUMENTS:
  -n <n_parc>     parcellation granularity used. Possible values are: 100, 200, 300 and 400
                  [ default: 300 ]
  -p <preproc>    preprocessing used for input data. Possible options are:
                  'minimal': for data only processed with the HCP minimal preprocessing pipeline
                  'fix': for data processed with 'minimal' and ICA-FIX
                  [ default: 'fix' ]
  -c <corr>       correlation method to use for computing FC. Possible options are:
                  'Pearson': Pearson (or full) correlation
                  'partial_l2': partial correlation with L2 regularisation
                  [ default: 'Pearson' ]
  -s <sub_list>   absolute path to the subject-list file, where each line of the file contains the 
                  subject ID of one HCP subject (e.g. '100206').
                  [ default: $BIN_DIR/sublist/HCP_surf_\$preproc_allRun_sub.csv ]
  -i <sub_id>     subject ID of the specific subject to run (e.g. '100206')
                  [ default: unset ]
  -o <output_dir> absolute path to output directory
                  [ default: $(pwd)/results/FC ]
  -h              display help message

OUTPUTS:
  $0 will create 1 output file in the output directory for each subject
  For example: HCP_fix_parc300_sub100206_REST1_LR_Pearson.mat

EXAMPLE:
  $0 -d \$(pwd)/results/parcellation
  $0 -d \$(pwd)/results/parcellation -n 100 -p minimal -c partial_l2 -i 100206

" 1>&2; exit 1; }

#Display help message if no argument is supplied
if [ $# -eq 0 ]; then
  usage; 1>&2; exit 1
fi

###########################################
# Parse arguments
###########################################

# Default parameters
n_parc=300
preproc=fix
corr=Pearson
output_dir=$(pwd)/results/FC

# Assign arguments
while getopts "n:p:c:d:s:i:o:h" opt; do
  case $opt in
    n) n_parc=${OPTARG} ;;
    p) preproc=${OPTARG} ;;
    c) corr=${OPTARG} ;;
    d) input_dir=${OPTARG} ;;
    s) sub_list=${OPTARG} ;;
    i) sub_id=${OPTARG} ;;
    o) output_dir=${OPTARG} ;;
    h) usage; exit ;;
    *) usage; 1>&2; exit 1 ;;
  esac
done

# Default subject-list
if [ -z $sub_list ]; then
  sub_list=$BIN_DIR/sublist/HCP_surf_${preproc}_allRun_sub.csv
fi

###########################################
# Check parameters
###########################################

if [ -z $input_dir ]; then
  echo "Input directory not defined."; 1>&2; exit 1;
fi

###########################################
# Other set-ups
###########################################

# Make sure output directory is set up
if [ ! -d $out_dir ]; then
  echo "Output directory does not exist. Creating now..."
  mkdir -p $out_dir
fi

###########################################
#Implementation
###########################################

main
