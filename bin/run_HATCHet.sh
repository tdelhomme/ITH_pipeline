#!/bin/bash

REF=$0
SAM=$1
BCF=$2
BNPY=$3

HATCHET_HOME=$4
HATCHET="${HATCHET_HOME}/bin/HATCHet.py"
UTILS="${HATCHET_HOME}/utils/"
SOLVER="${HATCHET_HOME}/build/solve"

XDIR="/data/gcs/mesomics/work/delhommet/HATCHet/B00JAKECD/"
NORMAL="/data/gcs/mesomics/work/delhommet/HATCHet/B00JAKECD/B00JAKE_alt_HGV5FCCXY.DUAL171.3_BQSRecalibrated.bam"
BAMS="/data/gcs/mesomics/work/delhommet/HATCHet/B00JAKECD/B00JAKC_alt_HGVWWCCXY.DUAL169.7-HGVWWCCXY.DUAL169.6_merged_BQSRecalibrated.bam /data/gcs/mesomics/work/delhommet/HATCHet/B00JAKECD/B00JAKD_alt_HGV5FCCXY.DUAL170.1-HGV5FCCXY.DUAL170.2_merged_BQSRecalibrated.bam"
ALLNAMES="B00JAKE B00JAKC B00JAKD"
NAMES="B00JAKC B00JAKD"
J=32 # number of cpu used to run hatchet

set -e
set -o xtrace
PS4='\''[\t]'\'
export PATH=$PATH:${SAM}
export PATH=$PATH:${BCF}

BIN=${XDIR}bin/
mkdir -p ${BIN}
BAF=${XDIR}baf/
mkdir -p ${BAF}
BB=${XDIR}bb/
mkdir -p ${BB}
BBC=${XDIR}bbc/
mkdir -p ${BBC}
ANA=${XDIR}analysis/
mkdir -p ${ANA}
RES=${XDIR}results/
mkdir -p ${RES}
EVA=${XDIR}evaluation/
mkdir -p ${EVA}

cd ${XDIR}

# run binBAM
python2 ${UTILS}binBAM.py -N ${NORMAL} -T ${BAMS} -S ${ALLNAMES} \
                                   -b 50kb -g hg38 -j ${J} \
                                   -q 20 -O ${BIN}normal.bin -o ${BIN}bulk.bin -v &> ${BIN}bins.log

# run deBAF
python2 ${UTILS}deBAF.py -N ${NORMAL} -T ${BAMS} -S ${ALLNAMES} \
                                  -r ${REF} -j ${J} -q 20 -Q 20 -U 20 -c 4 \
                                  -C 300 -O ${BAF}normal.baf -o ${BAF}bulk.baf -v \
                                  &> ${BAF}bafs.log

# run comBBo
python2 ${UTILS}comBBo.py -c ${BIN}normal.bin -C ${BIN}bulk.bin -B ${BAF}bulk.baf -m MIRROR -e 12 > ${BB}bulk.bb

# run cluBB
python2 ${UTILS}cluBB.py ${BB}bulk.bb -by ${BNPY} -o ${BBC}bulk.seg -O ${BBC}bulk.bbc \
                                              -e 12 -tB 0.04 -tR 0.15 -d 0.08

cd ${ANA}
python2 ${UTILS}BBot.py -c RD --figsize 6,3 ${BBC}bulk.bbc &
python2 ${UTILS}BBot.py -c CRD --figsize 6,3 ${BBC}bulk.bbc &
python2 ${UTILS}BBot.py -c BAF --figsize 6,3 ${BBC}bulk.bbc &
python2 ${UTILS}BBot.py -c BB ${BBC}bulk.bbc &
python2 ${UTILS}BBot.py -c CBB ${BBC}bulk.bbc &
wait

cd ${RES}
python2 ${HATCHET} ${SOLVER} -i ${BBC}bulk -n2,6 -p 100 -v 2 -u 0.1 -r 12 - j ${J} -eD 6 -eT 12 -l 0.5 &> >(tee >(grep -v Progress > hatchet.log))

## Increase -l to 0.6 to decrease the sensitivity in high-variance or noisy samples, and decrease it to -l 0.3 in low-variance samples to increase the sensitivity and explore multiple solutions with more clones.
## Increase -u if solutions have clone proportions equal to the minimum threshold -u
## Decrease the number of restarts to 200 or 100 for fast runs, as well as user can decrease the number of clones to -n 2,6 when appropriate or when previous runs suggest fewer clones.
## Increase the single-clone confidence to `-c 0.6` to increase the confidence in the presence of a single tumor clone and further increase this value when interested in a single clone.

cd ${EVA}
python ${UTILS}BBeval.py ${RES}/best.bbc.ucn
