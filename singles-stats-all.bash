#!/bin/bash

./nextflow run singles-stats-norm.nf 
sleep 1
./nextflow run singles-stats-lambda.nf 
sleep 1
./nextflow run singles-stats-global.nf
sleep 1
./nextflow run singles-stats-schedules.nf 
sleep 1
./nextflow run singles-stats.nf
