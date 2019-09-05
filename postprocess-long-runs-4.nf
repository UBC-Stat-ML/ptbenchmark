#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.runFolder
params.model


process plot {
  input:
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
  
  ess <- read.df("../../../${params.runFolder}/deliverables/main/aggregates/allEss", "csv", header="true", inferSchema="true")
  ess <- collect(ess)
  
  restarts <- read.df("../../../${params.runFolder}/deliverables/main/aggregates/actualTemperedRestarts", "csv", header="true", inferSchema="true")
  restarts <- collect(restarts)
  
  require("dplyr")
  require("stringr")
  ess <- ess %>%
    mutate(model = str_replace(model, ".*[.]", "")) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>%
    filter(variable != "allLogDensities") %>%
    filter(variable != "energy") %>%
    filter(method != "Single-chain MCMC") %>%
    mutate(
      isStochasticOpt = ifelse(str_detect(engine, "baselines.StochasticOptimizedPT"), 1, 0),  #(if (strcmp(engine,"baselines.StochasticOptimizedPT")) 1 else 0),
      postAdaptTime_ms = postAdaptTime_ms/(isStochasticOpt+1)
    )
          

  
  p <- ggplot(ess, aes(x = method, y = value/samplingTime_ms*1000, colour = method)) +
    geom_boxplot() +
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("ESS/s") +
    ggtitle(str_replace_all("${params.model}","[_]"," ")) + 
    scale_y_log10() + 
    theme_bw()  
  ggsave("ess-per-total-time-${params.model}.pdf", p, width = 8, height = 3, limitsize = FALSE)
  

  
  max_round <- max(restarts\$round)
  restarts <- restarts %>%
    filter(round == max_round | engine != "PT")
  
  p <- ggplot(restarts, aes(x = method, y = rate, colour = method)) +
    geom_boxplot() +
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("Tempered restart rate") +
    scale_y_log10() + 
    ggtitle(str_replace_all("${params.model}","[_]"," ")) + 
    theme_bw()  
  ggsave("restarts-${params.model}.pdf", p, width = 8, height = 3, limitsize = FALSE)
  write.csv(restarts, "restarts-${params.model}.csv")
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
