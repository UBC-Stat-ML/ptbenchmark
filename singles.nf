#!/usr/bin/env nextflow

/**
  Faster version of ELE tests, where only 1 seed is used, upper-bound decreased by a bit.
*/



params.model = "Ising-critical"

deliverableDir = 'deliverables' + '/' + workflow.scriptName.replace('.nf','') + '/' + params.model

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '628cbac8620f7736a3d51b1575bf51c45f71088c'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

process inference {
  input:
    file code
    file data
  output:
    file 'results/latest' into results
  publishDir deliverableDir, mode: 'link', overwrite: true
  """
  code/bin/blangDemos ${params.model} \
    --engine PT \
    --engine.nChains 30 \
    --engine.nScans 10_000 \
    --engine.nThreads MAX \
    --postProcessor DefaultPostProcessor 
  """
}

process summarizePipeline {
  cache false
  output:
      file 'pipeline-info.txt'   
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  echo 'scriptName: $workflow.scriptName' >> pipeline-info.txt
  echo 'start: $workflow.start' >> pipeline-info.txt
  echo 'runName: $workflow.runName' >> pipeline-info.txt
  echo 'nextflow.version: $workflow.nextflow.version' >> pipeline-info.txt
  """
}
