#!/bin/bash

all_models="elliptic Ising-critical discrete rockets ariane normal magnetic Ising-supercritical titanic"
default_options="-resume -qs 1"


# for model in $all_models
# do
#   ./nextflow run singles.nf $default_options --model $model
# done


#
# Experiments concerning the Efficient Local Exploration assumption
#

for model in magnetic elliptic Ising-supercritical discrete Ising-critical rockets
do
  ./nextflow run ele.nf $default_options --model $model 
done

# for outputFile in actualTemperedRestarts asymptoticRoundTripBound
# do 
#   for model in $all_models
#   do
#     ./nextflow run ele-fast.nf $default_options --model $model --outputFile $outputFile 
#   done
# done

#
# Benchmarking experiments
#

# for model in $all_models
# do
#   ./nextflow run benchmark.nf $default_options --model $model 
# done
