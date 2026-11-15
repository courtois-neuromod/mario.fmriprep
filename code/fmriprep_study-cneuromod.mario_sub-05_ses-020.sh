#!/bin/bash
#SBATCH --account=def-pbellec
#SBATCH --job-name=fmriprep_study-cneuromod.mario_sub-05_ses-020.job
#SBATCH --output=/scratch/bpinsard/mario.fmriprep/code/fmriprep_study-cneuromod.mario_sub-05_ses-020.out
#SBATCH --error=/scratch/bpinsard/mario.fmriprep/code/fmriprep_study-cneuromod.mario_sub-05_ses-020.err
#SBATCH --time=18:00:00
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=4096M
#SBATCH --tmp=100G
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=basile.pinsard@gmail.com

 
set -e -u -x


export LOCAL_DATASET=$SLURM_TMPDIR/${SLURM_JOB_NAME//-/}/
export SINGULARITYENV_TEMPLATEFLOW_HOME="${LOCAL_DATASET}/sourcedata/templateflow/"
flock --verbose /scratch/bpinsard/mario.fmriprep/.datalad_lock datalad clone /scratch/bpinsard/mario.fmriprep@base $LOCAL_DATASET
cd $LOCAL_DATASET
datalad get -s ria-beluga-storage -J 4 -n -r -R1 . # get sourcedata/* containers
datalad get -s ria-beluga-storage -J 4 -r sourcedata/templateflow/tpl-{MNI152NLin2009cAsym,OASIS30ANTs,fsLR,fsaverage,MNI152NLin6Asym}
if [ -d sourcedata/smriprep ] ; then
    datalad get -n sourcedata/smriprep sourcedata/smriprep/sourcedata/freesurfer
fi
git submodule foreach --recursive git annex dead here
git checkout -b $SLURM_JOB_NAME
# when freesurfer is ran in the meantime as s/fmriprep
if [ -d sourcedata/freesurfer ] ; then
  git -C sourcedata/freesurfer checkout -b $SLURM_JOB_NAME
fi

git submodule foreach  --recursive bash -c "git-annex enableremote ria-beluga-storage || true"
git submodule foreach  --recursive bash -c "git-annex enableremote ria-beluga-storage-local || true"


datalad containers-run -m 'fMRIPrep_sub-05/ses-020' -n bids-fmriprep --input sourcedata/templateflow/tpl-MNI152NLin2009cAsym/ --input sourcedata/templateflow/tpl-OASIS30ANTs/ --input sourcedata/templateflow/tpl-fsLR/ --input sourcedata/templateflow/tpl-fsaverage/ --input sourcedata/templateflow/tpl-MNI152NLin6Asym/ --output . --input 'sourcedata/cneuromod.mario/sub-05/ses-020/fmap/' --input 'sourcedata/cneuromod.mario/sub-05/ses-020/func/'  --input 'sourcedata/smriprep/sub-05/anat/' --input sourcedata/smriprep/sourcedata/freesurfer/fsaverage/ --input sourcedata/smriprep/sourcedata/freesurfer/sub-05/ -- -w ./workdir --participant-label 05 --anat-derivatives sourcedata/smriprep --fs-subjects-dir sourcedata/smriprep/sourcedata/freesurfer --bids-filter-file code/fmriprep_study-cneuromod.mario_sub-05_ses-020_bids_filters.json --output-layout bids --ignore slicetiming --use-syn-sdc --output-spaces MNI152NLin2009cAsym T1w:res-iso2mm --cifti-output 91k --notrack --write-graph --skip_bids_validation --omp-nthreads 8 --nprocs 12 --mem_mb 45056 --fs-license-file code/freesurfer.license  --track-carbon sourcedata/cneuromod.mario ./ participant 
fmriprep_exitcode=$?

flock --verbose /scratch/bpinsard/mario.fmriprep/.datalad_lock datalad push -d ./ --to origin
if [ -d sourcedata/freesurfer ] ; then
    flock --verbose /scratch/bpinsard/mario.fmriprep/.datalad_lock datalad push -J 4 -d sourcedata/freesurfer --to origin
fi 
if [ -e $LOCAL_DATASET/workdir/fmriprep_wf/resource_monitor.json ] ; then cp $LOCAL_DATASET/workdir/fmriprep_wf/resource_monitor.json /scratch/bpinsard/fmriprep_study-cneuromod.mario_sub-05_ses-020_resource_monitor.json ; fi 
if [ $fmriprep_exitcode -ne 0 ] ; then cp -R $LOCAL_DATASET /scratch/bpinsard/fmriprep_study-cneuromod.mario_sub-05_ses-020 ; fi 
exit $fmriprep_exitcode 
