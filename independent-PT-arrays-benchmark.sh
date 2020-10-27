#!/bin/bash

./nextflow run independent-PT-arrays-benchmark.nf -resume --model simple-mix-150 --baseNPassesPerScan 0.1 | nf-monitor

./nextflow run independent-PT-arrays-benchmark.nf -resume --model Ising-supercritical --baseNPassesPerScan 2 | nf-monitor

./nextflow run independent-PT-arrays-benchmark.nf -resume --model transfection --baseNPassesPerScan 4 | nf-monitor   