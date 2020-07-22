#!/usr/bin/env nextflow

/**
  Faster version of ELE tests, where only 1 seed is used, upper-bound decreased by a bit.
*/

deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

params.model = "Ising-supercritical"
params.outputFile = "actualTemperedRestarts"

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
    each nPassesPerScan from 0.04,0.125
    each nChains from 3,4,5,6,7,8,9,10,20,40,80,160,320
    each M from 5
  output: 
    file 'results/latest' into results
  publishDir "${deliverableDir}/M_${M}/nChains_${nChains}/nPassesPerScan_${nPassesPerScan}/", mode: 'symlink', overwrite: true
  """
  code/bin/blangDemos ${params.model} \
    --model.N $M \
    --model.moment 0.1 \
    --engine PT \
    --engine.nChains $nChains \
    --engine.nScans 50000 \
    --engine.nPassesPerScan $nPassesPerScan \
    --postProcessor DefaultPostProcessor 
  """
}

// process analysisCode {
//   input:
//     val gitRepoName from 'nedry'
//     val gitUser from 'alexandrebouchard'
//     val codeRevision from 'cf1a17574f19f22c4caf6878669df921df27c868'
//     val snapshotPath from "${System.getProperty('user.home')}/w/nedry"
//   output:
//     file 'code' into analysisCode
//   script:
//     template 'buildRepo.sh'
// }

// process aggregate {
//   input:
//     file analysisCode
//     file 'exec_*' from results.toList()
//   output:
//     file 'results/latest/aggregated' into aggregated
//   """
//   code/bin/aggregate \
//     --dataPathInEachExecFolder monitoring/${params.outputFile}.csv \
//     --keys \
//       engine.nPassesPerScan as nPassesPerScan \
//       engine.nChains as nChains \
//            from arguments.tsv
//   """
// }

// process plot {
//   input:
//     file aggregated
//     env SPARK_HOME from "${System.getProperty('user.home')}/bin/spark-2.1.0-bin-hadoop2.7"
    
//    output:
//     file '*.pdf'
//     file '*.csv'

//   publishDir deliverableDir, mode: 'copy', overwrite: true
  
//   afterScript 'rm -r metastore_db; rm derby.log'
    
//   """
//   #!/usr/bin/env Rscript
//   require("ggplot2")
//   library(SparkR, lib.loc = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib")))
//   sparkR.session(master = "local[*]", sparkConfig = list(spark.driver.memory = "4g"))
  
//   data <- read.df("$aggregated", "csv", header="true", inferSchema="true")
//   data <- collect(data)
  
//   max_round <- max(data\$round)
  
//   require("dplyr")
//   data <- data %>%
//     filter(round == max_round)
  
//   p <- ggplot(data, aes(x = nPassesPerScan, y = rate)) +
//     geom_line() +
//     theme_bw() 
//   write.csv(data, "${params.model}-${params.outputFile}-summary.csv")
//   ggsave("${params.model}-${params.outputFile}-summary.pdf", p, width = 10, height = 5, limitsize = FALSE)
//   """
// }


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
