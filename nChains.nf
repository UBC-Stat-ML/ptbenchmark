#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.model = "ising"

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from 'b4a0593e172afc1c454b70eb20144eac0f07460f'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

seeds = (1..10).collect{it}
process inference {
  input:
    file code
    file data
    each seed from seeds
    each multiplier from 2,4,8,16,32,64
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos ${params.model} \
    --engine PT \
    --engine.random $seed \
    --engine.nChains ${10 * multiplier} \
    --engine.nScans 50000 \
    --engine.nThreads MAX \
    --engine.nPassesPerScan 0.5 \
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

results.into {
  results1
  results2
  results3
}

process aggregate {
  input:
    file analysisCode
    file 'exec_*' from results1.toList()
  output:
    file 'results/latest/aggregated' into aggregated
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder monitoring/actualTemperedRestarts.csv \
    --keys \
      engine.nChains as nChains \
      engine.random as mcRand \
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
  
  require("dplyr")
  data <- data %>%
    group_by(round, nChains) %>%
    summarize(meanRate = mean(rate))
  
  p <- ggplot(data, aes(x = round, y = meanRate, colour = factor(nChains))) +
    scale_colour_discrete(name="Number of parallel chains") + 
    geom_line() +
    theme_bw()  
  ggsave("${params.model}-nChains.pdf", p, width = 10, height = 5, limitsize = FALSE)
  write.csv(data, "${params.model}-nChains.csv")
  """
}

process aggregate2 {
  input:
    file analysisCode
    file 'exec_*' from results2.toList()
  output:
    file 'results/latest/aggregated' into aggregated2
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder monitoring/asymptoticRoundTripBound.csv \
    --keys \
      engine.nChains as nChains \
      engine.random as mcRand \
           from arguments.tsv
  """
}

process plot2 {
  input:
    file aggregated2
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
  
  data <- read.df("$aggregated2", "csv", header="true", inferSchema="true")
  data <- collect(data)
  
  require("dplyr")
  data <- data %>%
    group_by(round, nChains) %>%
    summarize(meanRate = mean(rate))
  
  p <- ggplot(data, aes(x = round, y = meanRate, colour = factor(nChains))) +
    scale_colour_discrete(name="Number of parallel chains") + 
    geom_line() +
    theme_bw()  
  ggsave("${params.model}-nChains-bound.pdf", p, width = 10, height = 5, limitsize = FALSE)
  write.csv(data, "${params.model}-nChains-bound.csv")
  """
}

process aggregate3 {
  input:
    file analysisCode
    file 'exec_*' from results3.toList()
  output:
    file 'results/latest/aggregated' into aggregated3
  """
  code/bin/aggregate \
    --dataPathInEachExecFolder monitoring/lambdaInstantaneous.csv \
    --keys \
      engine.nChains as nChains \
      engine.random as mcRand \
           from arguments.tsv
  """
}

process plot3 {
  input:
    file aggregated3
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
  
  data <- read.df("$aggregated3", "csv", header="true", inferSchema="true")
  data <- collect(data)
  
  require("dplyr")
  data <- data %>%
    filter(isAdapt == F) %>%
    group_by(beta, nChains) %>%
    summarize(meanRate = mean(value))
  
  p <- ggplot(data, aes(x = beta, y = meanRate, colour = factor(nChains))) +
    scale_colour_discrete(name="Number of parallel chains") + 
    geom_line() +
    theme_bw()  
  ggsave("${params.model}-lambda.pdf", p, width = 10, height = 5, limitsize = FALSE)
  write.csv(data, "${params.model}-lambda.csv")
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
