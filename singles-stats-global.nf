#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')



process analysisCode {
  input:
    val gitRepoName from 'nedry'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '70f606d6b6534bb6c72dfc49b6f4c76abdf258c8'
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
    each stat from 'globalLambda'
  output:
    file '*.csv.gz' into aggregated
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate  \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false \
    --execFoldersPrefix /Users/bouchard/experiments/ptbenchmark/deliverables/singles/exec_ \
    --dataPathInEachExecFolder results/latest/monitoring/${stat}.csv \
    --keys \
      model \
           from results/latest/arguments.tsv
  mv results/latest/aggregated.csv.gz ${stat}.csv.gz
  """
}

process plot {
  echo true
  input:
    file aggregated
  output:
    file '*.pdf'
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  
  data <- read.csv("$aggregated")  %>% filter(round <= 12)  %>%
    mutate(execFolder = str_replace(execFolder, "exec_", ""))
    
  p <- ggplot(data, aes(x = round, y = value)) +
    facet_wrap(~ execFolder, scales = "free_y") + 
    ylab(expression(Lambda)) + 
    geom_line() + 
    theme_bw()
    
  ggsave("globalLambda-progress.pdf", width = 7, height = 7)
  
  
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
