#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.model = "ising"
params.baseNPassesPerScan = 0.1

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'c80d739ca20796b5e844680acd21d353c4d3886d'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

seeds = (1..10).collect{it}

baselineNIters = 50000
baseThinning = 50
ks = (1..5)
parallelBudget = 40
fs = (-1..1).collect{Math.pow(2,it)}

process inference {
  input:
    file code
    file data
    each seed from seeds
    each k from ks
    each f from fs
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos ${params.model} \
    --engine.random $seed \
    --engine.nChains ${(parallelBudget/k).toInteger()} \
    --engine.nScans ${f*baselineNIters} \
    --engine.thinning ${f*baseThinning} \
    --engine.nPassesPerScan ${params.baseNPassesPerScan/f} \
    --engine.nThreads Single \
    --postProcessor NoPostProcessor \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false 
  echo "\nk\t${k}" >> results/latest/arguments.tsv
  echo "\nf\t${f}" >> results/latest/arguments.tsv
  """
}

process analysisCode {
  input:
    val gitRepoName from 'nedry'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '93930421f33027466653adc297532faa3e58412c'
    val snapshotPath from "${System.getProperty('user.home')}/w/nedry"
  output:
    file 'code' into analysisCode
  script:
    template 'buildRepo.sh'
}

process aggregate {
  echo true
  input:
    file analysisCode
    file 'exec_*' from results.toList()
  output:
    file '*.csv' into aggregated
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder monitoring/actualTemperedRestarts.csv.gz \
    --keys \
      engine.nPassesPerScan as nPassesPerScan \
      engine.nChains as nChains \
      k \
      f as swap_frequency \
      engine.random as mcRand \
           from arguments.tsv
  mv results/latest/aggregated.csv independent-PT-arrays-${params.model}.csv
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
  data <- data %>% mutate(roundTripPerParallelizedComputeCost = count * k)
  
  summary <- data %>% 
    group_by(swap_frequency, k) %>%
    summarize(
      m = mean(roundTripPerParallelizedComputeCost),
      se = sd(roundTripPerParallelizedComputeCost)/sqrt(length(roundTripPerParallelizedComputeCost))
    )
  
  p <- ggplot(summary, aes(x = k, y = m, colour = swap_frequency, group = swap_frequency)) +
    xlab("Number of independent PT arrays") + 
    ylab("Round trips in all arrays per compute cost (algorithms parallelized over chains and PT arrays)") + 
    ggtitle("Constant number of cores used: ${parallelBudget}", 
      subtitle = "Number of chains: ${parallelBudget}/number of PT arrays") +
    geom_errorbar(aes(ymin=m-se, ymax=m+se), width=.1) +
    geom_line() +
    geom_point() +
    theme_bw()
    
  ggsave(plot = p, filename = paste0("independent-PT-arrays-${params.model}.pdf"))
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
