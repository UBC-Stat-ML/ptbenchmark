#!/usr/bin/env nextflow

workflowName = workflow.scriptName.replace('.nf','')
deliverableDir = 'deliverables/' + workflowName

params.model = "Ising-supercritical"

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'bfbdecf3848d7291f94d726e0144ee714d0d26fa'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

seeds = (1..10).collect{it}
budgets = (0..5).collect{Math.pow(2,it)}

process inference {
  input:
    file code
    file data
    each seed from seeds
    each budget from budgets
    each method from 'PT-10', 'PT-20', 'PT-40', 'PT-80', 'SCM'
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos ${params.model} \
    --engine.random $seed \
    ${
      if (method == "PT-10") ("--engine PT --engine.nPassesPerScan 0.5 --engine.nScans " + 1000*budget + " --engine.nChains " + 10) else ""
    } ${
      if (method == "PT-20") ("--engine PT --engine.nPassesPerScan 0.5 --engine.nScans " + 1000*budget + " --engine.nChains " + 20) else ""
    } ${
      if (method == "PT-40") ("--engine PT --engine.nPassesPerScan 0.5 --engine.nScans " + 2000*budget + " --engine.nChains " + 40) else ""
    } ${
      if (method == "PT-80") ("--engine PT --engine.nPassesPerScan 0.5 --engine.nScans " + 4000*budget + " --engine.nChains " + 80) else ""
    } ${
      if (method == "SCM") ("--engine SCM --engine.nParticles " + 1000*budget) else ""
    } \
    --engine.nThreads Single \
    --postProcessor NoPostProcessor \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false 
  echo "\nbudget\t${budget}" >> results/latest/arguments.tsv
  echo "\nmethod\t${method}" >> results/latest/arguments.tsv
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
    file '*.csv.gz' into aggregated
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false \
    --dataPathInEachExecFolder logNormalizationEstimate.csv.gz \
    --keys \
      budget \
      method \
      engine.random as mcRand \
                                 from arguments.tsv, \
      samplingTime_ms            from monitoring/runningTimeSummary.tsv
  mv results/latest/aggregated.csv.gz ${workflowName}-${params.model}.csv.gz
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
  
  data <- data %>% filter(estimator != "SMC-initialization")
  
  #meanTimes <- data %>% group_by(budget, engine) %>% 
  
  p <- ggplot(data, aes(x = samplingTime_ms, y = value, colour = budget, shape = method)) + 
    geom_point() +
    scale_x_log10() + 
    theme_bw()
    
  ggsave("comparison.pdf")
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
