require("tidyverse")

mu0_30 <- read.csv("30-chain/samples/firstComponentMean.csv.gz")
mu0_1 <- read.csv("1-chain/samples/firstComponentMean.csv.gz")

logd_30 <- read.csv("30-chain/samples/logDensity.csv.gz")
logd_1 <- read.csv("1-chain/samples/logDensity.csv.gz")

combined <- bind_rows(mu0_30, mu0_1, logd_30, logd_1, .id = "id") %>% 
  filter(sample >= 2500) %>%
  mutate(
    statistic = ifelse(id == 1 | id == 2, "X_i", "V(X)"),
    sampler = ifelse(id == 1 | id == 3, "Non reversible PT (30 chains)", "Exploration kernel alone (1 chain)")
  )

p <- ggplot(combined, aes(x = sample, y = value)) +
  facet_grid(statistic ~ sampler, scales = "free") +
  ylab("Sample") + 
  xlab("MCMC iteration") +
  geom_point(size = 0.1) +
  geom_line(alpha = 0.5) +
  theme_bw()

ggsave("mixture-V_vs_X.pdf", height = 3, width = 6)



