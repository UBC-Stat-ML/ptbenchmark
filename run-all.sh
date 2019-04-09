#!/bin/bash

all_models="elliptic ising titanic"
default_options="-resume -qs 1"

for model in elliptic ising
do
  ./nextflow run ele.nf $default_options --model $model 
done

for outputFile in actualTemperedRestarts asymptoticRoundTripBound
do 
  for model in $all_models
  do
    ./nextflow run ele-fast.nf $default_options --model $model --outputFile $outputFile 
  done
done

for model in $all_models
do
  ./nextflow run benchmark.nf $default_options --model $model 
done
