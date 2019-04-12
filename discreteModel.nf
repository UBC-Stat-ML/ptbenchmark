#!/usr/bin/env nextflow

/**
  Check agreement of theory and numerics on a discrete multimodal problem.
*/

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'fe6a90d070e6ee301f37400213f733e9bc1a40cc'
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
    each a from 100.0,1000.0
    each k from 1,2
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos discrete \
    --engine PT \
    --engine.nChains 20 \
    --engine.nScans 10_000 \
    --engine.nThreads MAX \
    --model.k $k \
    --model.a $a \
    --postProcessor NoPostProcessor 
  """
}

process analysisCode {
  input:
    val gitRepoName from 'nedry'
    val gitUser from 'alexandrebouchard'
    val codeRevision from 'cf1a17574f19f22c4caf6878669df921df27c868'
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
    file 'results/latest/aggregated' into aggregated
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder monitoring/lambdaInstantaneous.csv \
    --keys \
      model.k as k \
      model.a as a \
           from arguments.tsv
  """
}

process plot {
  input:
    file aggregated
    env SPARK_HOME from "${System.getProperty('user.home')}/bin/spark-2.1.0-bin-hadoop2.7"
    
   output:
    file '*.pdf'
    file '*.csv'

  publishDir deliverableDir, mode: 'copy', overwrite: true
  
  afterScript 'rm -r metastore_db; rm derby.log'
    
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  library(SparkR, lib.loc = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib")))
  sparkR.session(master = "local[*]", sparkConfig = list(spark.driver.memory = "4g"))
  
  data <- read.df("$aggregated", "csv", header="true", inferSchema="true")
  data <- collect(data)
  
  max_round <- max(data\$round)
  
  require("dplyr")
  data <- data %>%
    filter(round == max_round)
  
  p <- ggplot(data, aes(x = beta, y = value)) +
    geom_line() +
    facet_grid(k ~ a) +
    theme_bw() 
  write.csv(data, "lambda.csv")
  ggsave("lambda.pdf", p, width = 10, height = 10, limitsize = FALSE)
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
