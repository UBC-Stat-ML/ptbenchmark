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
    file 'vertices.csv.gz' into vertices
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  code/bin/aggregate  \
    --experimentConfigs.tabularWriter.compressed true \
    --experimentConfigs.resultsHTMLPage false \
    --execFoldersPrefix /Users/bouchard/experiments/ptbenchmark/analyses/not-scm/ising/exec_ \
    --dataPathInEachExecFolder samples/vertices.csv.gz \
    --keys \
      engine from arguments.tsv
  mv results/latest/aggregated.csv.gz vertices.csv.gz
  """
}


process plot {
  input:
    file vertices
  output:
    file '*.pdf'
  publishDir deliverableDir, mode: 'copy', overwrite: true
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  require("stringr")
  
  data <- read.csv("$vertices") %>% filter(index_0 < 20, sample < 1000)
  
  data\$execFolder <- str_replace(data\$execFolder, "exec_", "")
  
  ggplot(data, aes(x = 2*value - 1)) + 
    geom_histogram() + 
    facet_grid(index_0 ~ execFolder) + 
    scale_x_continuous("Vertex configuration", breaks = c(-1, 1), limits = c(-2, 2)) + 
    theme_bw()
  
  ggsave("vertices.pdf", width = 8, height = 15)
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
