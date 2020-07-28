require("tidyverse")

this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

beta_50 <- read.csv("50-chain/samples/beta.csv")
beta_1 <- read.csv("1-chain/samples/beta.csv")

logd_50 <- read.csv("50-chain/samples/energy.csv") %>% filter(chain == 0)
logd_1 <- read.csv("1-chain/samples/energy.csv") %>% filter(chain == 0)

combined <- bind_rows(beta_50, beta_1, logd_50, logd_1, .id = "id") %>% 
  filter(sample >= 5000) %>%
  mutate(
    statistic = ifelse(id == 1 | id == 2, "Beta", "V(X)"),
    sampler = ifelse(id == 1 | id == 3, "Non reversible PT (50 chains)", "Local exploration kernel alone (1 chain)")
  )

p <- ggplot(combined, aes(x = sample, y = value)) +
  facet_grid(statistic ~ sampler, scales = "free") +
  ylab("Sample") + 
  xlab("MCMC iteration") +
  geom_point(size = 0.1) +
  geom_line(alpha = 0.5) +
  theme_bw()

ggsave("transfection-V_vs_X.pdf", height = 3, width = 6)



