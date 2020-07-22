#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.model = "ising"

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '2ff9aaabc251830778fbd41c6a8b5b1a6054318c'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

seeds = (1..10).collect{it}

baselineNIters = 100000
baseThinning = 100
ks = (1..5)
parallelBudget = 20
fs = (0..2).collect{Math.pow(2,it)}

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
    --engine.nPassesPerScan ${0.1/f} \
    --engine.nThreads Single \
    --postProcessor NoPostProcessor \
    --experimentConfigs.tabularWriter.compressed true
  echo "\nk\t${k}" >> results/latest/arguments.tsv
  echo "\nf\t${f}" >> results/latest/arguments.tsv
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
    file 'results/latest/aggregated.csv' into aggregated
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
    ylab("Round trip per compute cost (parallelized over chains and PT arrays)") + 
    geom_errorbar(aes(ymin=m-se, ymax=m+se), width=.1) +
    geom_line() +
    geom_point() +
    theme_bw()
    
  ggsave(plot = p, filename = paste0("independent-PT-arrays-", "${params.model}", ".pdf"))
  """
}

//     scale_y_continuous(sec.axis = ~ ${parallelBudget}/.) + 



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
