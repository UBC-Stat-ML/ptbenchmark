require("ggplot2")
data <- read.csv("/Users/bouchard/experiments/ptbenchmark/work/6e/5698e1d9a1ecdfefb98a0710fe775a/results/all/2019-04-12-10-17-43-DLWik474.exec/monitoring/swapSummaries.csv")
p <- ggplot(data, aes(x = round, y = average)) +
  geom_line() +
  ylab("swapSummaries average") + 
  theme_bw()
ggsave("/Users/bouchard/experiments/ptbenchmark/work/6e/5698e1d9a1ecdfefb98a0710fe775a/results/all/2019-04-12-10-17-43-DLWik474.exec/monitoringPlots/swapSummaries.pdf", limitsize = F)
