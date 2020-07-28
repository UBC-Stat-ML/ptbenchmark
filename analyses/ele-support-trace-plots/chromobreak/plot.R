require("tidyverse")

this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

f0_50 <- read.csv("50-2020-07-26-08-40-46-YAs10RS8.exec/samples/f0.csv")
f0_1 <- read.csv("1-chain_2020-07-26-08-40-57-RtGpUME2.exec/samples/f0.csv")

logd_50 <- read.csv("50-2020-07-26-08-40-46-YAs10RS8.exec/samples/energy.csv") %>% filter(chain == 0)
logd_1 <- read.csv("1-chain_2020-07-26-08-40-57-RtGpUME2.exec/samples/energy.csv") %>% filter(chain == 0)

combined <- bind_rows(f0_50, f0_1, logd_50, logd_1, .id = "id") %>% 
  filter(sample >= 2500) %>%
  mutate(
    statistic = ifelse(id == 1 | id == 2, "Ploidity parameter", "V(X)"),
    sampler = ifelse(id == 1 | id == 3, "Non reversible PT (50 chains)", "Local exploration kernel alone (1 chain)")
  )

p <- ggplot(combined, aes(x = sample, y = value)) +
  facet_grid(statistic ~ sampler, scales = "free") +
  ylab("Sample") + 
  xlab("MCMC iteration") +
  geom_point(size = 0.1) +
  geom_line(alpha = 0.5) +
  theme_bw()

ggsave("chromo-V_vs_X.pdf", height = 3, width = 6)



