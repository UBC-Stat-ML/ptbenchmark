#!/usr/bin/env nextflow

workflowName = workflow.scriptName.replace('.nf','')
deliverableDir = 'deliverables/' + workflowName

params.model = "ising"
params.nChains = 50

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '1211f990611d7e1f163c8d92609cdda03c42af07'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

Ns = [1, params.nChains]

process inference {
  input:
    file code
    file data
    each N from Ns
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos ${params.model} \
    --engine.nChains $N \
    --postProcessor NoPostProcessor \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false 
  echo "\nbudget\t${budget}" >> results/latest/arguments.tsv
  """
}

process analysisCode {
  input:
    val gitRepoName from 'nedry'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'e7893230d0bb6b6dedad9499532f3716286e62ba'
    val snapshotPath from "${System.getProperty('user.home')}/w/nedry"
  output:
    file 'code' into analysisCode
  script:
    template 'buildRepo.sh'
}

process aggregate {
  input:
    file analysisCode
    file 'exec_*' from results.toList()
  output:
    file '*.csv' into aggregated
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder logNormalizationEstimate.csv.gz \
    --keys \
      budget \
      engine \
      engine.random as mcRand \
                                 from arguments.tsv \
      samplingTime_ms            from monitoring/runningTimeSummary.tsv
  mv results/latest/aggregated.csv ${workflowName}-${params.model}.csv
  """
}


process plot {
  input:
    file aggregated
  output:
    file '*.pdf'
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  
  data <- read.csv("$aggregated")
  
  data <- data %>% filter(method != "SMC-initialization")
  
  p <- ggplot(data, aes(x = samplingTime_ms, y = value, colour = budget, shape = engine)) + 
    geom_point() +
    theme_bw()
    
  ggsave(
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
