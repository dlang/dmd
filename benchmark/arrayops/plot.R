# Use `Rscript --vanilla plot.R old.csv new.csv` to run this script.
# It will read old.csv and new.csv files and create a comparison plot for them.
library(ggplot2)
library(dplyr)
library(tidyr)

dat <- NULL
args <- commandArgs(trailingOnly=T)
old <- read.csv(args[1]) %>% tbl_df()
new <- read.csv(args[2]) %>% tbl_df()

col.indices <- which(!colnames(new) %in% c("type", "op"))

# relative values
new[,col.indices] <- 100 * new[,col.indices] / old[,col.indices]

latencies <- gather(new %>% select(-starts_with('throughput')), num_elems, latency, starts_with('latency')) %>%
    mutate(num_elems = factor(as.integer(sub("latency(\\d+)", "\\1", num_elems))))
throughputs <- gather(new %>% select(-starts_with('latency')), array_size, throughput, starts_with('throughput')) %>%
    mutate(array_size = factor(as.integer(sub("throughput(\\d+)KB", "\\1", array_size))))

img <- qplot(num_elems, latency, group=type, data=latencies, geom="line", color=type) +
  facet_grid(op ~ ., scales="free_y") +
  labs(x="num elements", y="relative latency / %")
ggsave('array_ops_latency.png', plot = img, width = 8, height = 40)

img <- qplot(array_size, throughput, group=type, data=throughputs, geom="line", color=type) +
  facet_grid(op ~ ., scales="free_y") +
  labs(x="array size / KB", y="relative throughput / %")
ggsave('array_ops_throughput.png', plot = img, width = 8, height = 40)
