require("tidyverse")

this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

df50 <- read.csv("50-2020-07-26-08-40-46-YAs10RS8.exec/samples/nStates.csv")
df1 <- read.csv("1-chain_2020-07-26-08-40-57-RtGpUME2.exec/samples/nStates.csv")
dfmmv <- read.csv("MMV/samples/nStates.csv")
dfmmvdeo <- read.csv("MMV-DEO/samples/nStates.csv")

combined <- bind_rows(df50, df1, dfmmv, dfmmvdeo, .id = "id") %>% 
  filter(sample >= 2500) %>%
  mutate(
    sampler = ifelse(id == 1, "Non reversible PT (50 chains)", 
              ifelse(id == 2, "Expl. kernel alone (1 chain)", 
              ifelse(id == 3, "MMV", "MMV-DEO")))
  )

p <- ggplot(combined, aes(x = sample, y = value)) +
  facet_grid(chromosomes ~ sampler, scales = "free") +
  ylab("Sample") + 
  xlab("MCMC iteration") +
  geom_point(size = 0.1) +
  geom_line(alpha = 0.5) +
  theme_bw()

ggsave("chromo-nstates-traces.pdf", height = 12, width = 8)
ggsave("chromo-nstates-traces.png", height = 12, width = 8)



