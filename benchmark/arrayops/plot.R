# Use `R --vanilla < plot.R` to run this script.
# It will read all *.csv files from the current folder and create a comparison plot for them.
library(ggplot2)
library(dplyr)
library(tidyr)

dat <- NULL
files <- list.files(pattern='*.csv')
for (file in files)
{
  datFile <- read.csv(file) %>% tbl_df() %>%
    mutate(file=file)
  if (is.null(dat))
     dat = datFile
  else
     dat = bind_rows(dat, datFile)
}

latencies <- gather(dat %>% select(-starts_with('throughput')), num_elems, latency, starts_with('latency')) %>%
    mutate(num_elems = factor(as.integer(sub("latency(\\d+)", "\\1", num_elems))))
throughputs <- gather(dat %>% select(-starts_with('latency')), array_size, throughput, starts_with('throughput')) %>%
    mutate(array_size = factor(as.integer(sub("throughput(\\d+)KB", "\\1", array_size))))

img <- qplot(num_elems, latency, group=type, data=latencies, geom="line", color=type) +
  facet_grid(op ~ file, scales="free_y") +
  labs(x="num elements", y="latency / ns")
ggsave('array_ops_latency.png', plot = img, width = 2 + 3 * length(files), height = 40)

img <- qplot(array_size, throughput, group=type, data=throughputs, geom="line", color=type) +
  facet_grid(op ~ file, scales="free_y") +
  labs(x="array size / KB", y="throughput / (ops / ns)")
ggsave('array_ops_throughput.png', plot = img, width = 2 + 3 * length(files), height = 40)
