require("tidyverse")

this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

sum_20 <- read.csv("20-chain/samples/vertices.csv.gz") %>% group_by(sample) %>% summarise(value = 2*sum(value)-25)
sum_1 <- read.csv("1-chain/samples/vertices.csv.gz") %>% group_by(sample) %>% summarise(value = 2*sum(value)-25)

logd_20 <- read.csv("20-chain/samples/energy.csv.gz") %>% filter(chain == 0)
logd_1 <- read.csv("1-chain/samples/energy.csv.gz") %>% filter(chain == 0)

combined <- bind_rows(sum_20, sum_1, logd_20, logd_1, .id = "id") %>% 
  filter(sample >= 2500) %>%
  mutate(
    statistic = ifelse(id == 1 | id == 2, "sum(X)", "V(X)"),
    sampler = ifelse(id == 1 | id == 3, "Non reversible PT (20 chains)", "Local exploration kernel alone (1 chain)")
  )

p <- ggplot(combined, aes(x = sample, y = value)) +
  facet_grid(statistic ~ sampler, scales = "free") +
  ylab("Sample") + 
  xlab("MCMC iteration") +
  geom_point(size = 0.1) +
  geom_line(alpha = 0.5) +
  theme_bw()

ggsave("Ising-V_vs_X.pdf", height = 3, width = 6)



