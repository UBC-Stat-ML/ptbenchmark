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
  output:
    file 'means.csv.gz' into means
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate  \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false \
    --execFoldersPrefix /Users/bouchard/experiments/ptbenchmark/analyses/not-scm/simple-mix-300/exec_ \
    --dataPathInEachExecFolder samples/means.csv.gz \
    --keys \
      engine from arguments.tsv
  mv results/latest/aggregated.csv.gz means.csv.gz
  """
}


process plot {
  input:
    file means
  output:
    file '*.pdf'
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  
  data <- read.csv("$means")  %>% filter(value > 50 & value < 250)
  
  data\$execFolder <- str_replace(data\$execFolder, "exec_", "")
  
  p <- ggplot(data, aes(x = value)) +
    coord_flip() +
    ylab("Posterior density") + 
    xlab("Cluster parameter") + 
    facet_grid(index_0 ~ execFolder) + 
    geom_density() +
    theme_bw()
  
  ggsave("means.pdf", width = 10, height = 3)
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
