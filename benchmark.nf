#!/usr/bin/env nextflow

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.model = "ising"
params.nThreads
nThreads = params.nThreads
nNonReversibleChains = nThreads - 1 

process buildCode {
  input:
    val gitRepoName from 'blangDemos'
    val gitUser from 'UBC-Stat-ML'
    val codeRevision from '9dce9b5a06ae2ce6637ff5676afa3da1f6c4b0c8'
    val snapshotPath from "${System.getProperty('user.home')}/w/blangDemos"
  output:
    file 'code' into code
    file 'data' into data
  script:
    template 'buildRepo.sh' 
}

process inference {
  container 'cgrlab/tidyverse'
  input:
    file code
    file data
    each method from '--experimentConfigs.description Non-reversible PT            --engine PT --engine.nChains ' + nNonReversibleChains + ' --engine.initialization FORWARD',
                     '--experimentConfigs.description Non-reversible PT + SCM init --engine PT --engine.nChains ' + nNonReversibleChains + ' --engine.initialization SCM',
                     '--experimentConfigs.description Single-chain MCMC            --engine PT --engine.nChains 1',
                     '--experimentConfigs.description Atchade-Roberts-Rosenthal    --engine baselines.StochasticOptimizedPT --engine.scheme ARR --engine.reversible true', 
                     '--experimentConfigs.description Miasojedow-Moulines-Vihola   --engine baselines.StochasticOptimizedPT --engine.scheme MMV --engine.reversible true'
  output:
    file 'results/latest' into results
  """
  code/bin/blangDemos ${params.model} \
    ${method} \
    --engine.nScans 10_000 \
    --engine.nThreads fixed \
    --engine.nThreads.number ${params.nThreads} \
    --postProcessor DefaultPostProcessor 
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
    file 'aggregates' into aggregates
  """
  mkdir aggregates
  for file in "monitoring/actualTemperedRestarts" "ess/allEss"
  do 
    code/bin/aggregate \
      --dataPathInEachExecFolder \${file}.csv \
      --keys \
        \
        postAdaptTime_ms \
        samplingTime_ms \
             from monitoring/runningTimeSummary.tsv, \
        \
        model \
        engine \
        experimentConfigs.description as method  \
             from arguments.tsv
    mv results/latest/aggregated aggregates/`echo \${file} | sed 's-.*/--'`
  done
  """
}

process plot {
  container 'cgrlab/tidyverse'
  input:
    file aggregates
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
  
  ess <- read.df("$aggregates/allEss", "csv", header="true", inferSchema="true")
  ess <- collect(ess)
  
  restarts <- read.df("$aggregates/actualTemperedRestarts", "csv", header="true", inferSchema="true")
  restarts <- collect(restarts)
  
  require("dplyr")
  require("stringr")
  ess <- ess %>%
    mutate(model = str_replace(model, ".*[.]", "")) %>%
    mutate(model = str_replace(model, "[\$]Builder", "")) %>%
    filter(variable != "allLogDensities") %>%
    filter(variable != "energy") %>%
    mutate(
      isStochasticOpt = ifelse(str_detect(engine, "baselines.StochasticOptimizedPT"), 1, 0),  #(if (strcmp(engine,"baselines.StochasticOptimizedPT")) 1 else 0),
      postAdaptTime_ms = postAdaptTime_ms/(isStochasticOpt+1)
    )
          
  p <- ggplot(ess, aes(x = method, y = value, colour = method)) +
    geom_boxplot() +
    facet_grid(model ~ ., scales = "free") + 
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("ESS") +
    scale_y_log10() + 
    ggtitle("Effective Sample Size (ESS) across all model marginal distributions") + 
    theme_bw()  
  ggsave("ess-${params.model}.pdf", p, width = 10, height = 5, limitsize = FALSE)
  write.csv(ess, "ess+timing-${params.model}.csv")
  
  p <- ggplot(ess, aes(x = method, y = value/samplingTime_ms*1000, colour = method)) +
    geom_boxplot() +
    facet_grid(model ~ ., scales = "free") + 
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("ESS/s based on total wall clock time") +
    scale_y_log10() + 
    ggtitle("Effective Sample Size per total time (ESS/s) across all model marginal distributions", 
      subtitle = "Total wall clock time computed as the wall clock time for sampling + adaptation (if applicable)"
    ) + 
    theme_bw()  
  ggsave("ess-per-total-time-${params.model}.pdf", p, width = 10, height = 5, limitsize = FALSE)
  
  p <- ggplot(ess, aes(x = method, y = value/postAdaptTime_ms*1000, colour = method)) +
    geom_boxplot() +
    facet_grid(model ~ ., scales = "free") + 
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("ESS/s based on wall clock time excluding adaptation time") +
    scale_y_log10() + 
    ggtitle("Effective Sample Size per sampling time (ESS/s) across all model marginal distributions", 
      subtitle = "Total wall clock time computed as the wall clock time for sampling (excluding adaptation)"
    ) + 
    theme_bw()  
  ggsave("ess-per-sample-time-${params.model}.pdf", p, width = 10, height = 5, limitsize = FALSE)
  
  max_round <- max(restarts\$round)
  restarts <- restarts %>%
    filter(round == max_round | engine != "PT")
  
  p <- ggplot(restarts, aes(x = method, y = rate, colour = method)) +
    geom_boxplot() +
    facet_grid(model ~ ., scales = "free") + 
    guides(colour=FALSE) +
    xlab("Inference Method") + 
    ylab("Tempered restart rate") +
    scale_y_log10() + 
    ggtitle("Tempered restart rate") + 
    theme_bw()  
  ggsave("restarts-${params.model}.pdf", p, width = 10, height = 5, limitsize = FALSE)
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
