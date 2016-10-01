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

latencies <- gather(dat %>% select(-starts_with('throughput')), num_elems, latency, starts_with('latency'))
throughputs <- gather(dat %>% select(-starts_with('latency')), array_size, throughput, starts_with('throughput'))

levels(latencies$num_elems) <- sub("latency(\\d+)", "\\1", levels(latencies$num_elems))
levels(throughputs$array_size) <- sub("throughput(.+)", "\\1", levels(throughputs$array_size))

img <- qplot(num_elems, latency, group=type, data=latencies, geom="line", color=type) +
  facet_grid(op ~ file, scales="free_y") +
  labs(x="num elements", y="latency / ns")
ggsave('array_ops_latency.svg', plot = img, width = 2 + 3 * length(files), height = 40)

img <- qplot(array_size, throughput, group=type, data=throughputs, geom="line", color=type) +
  facet_grid(op ~ file, scales="free_y") +
  labs(x="array size", y="throughput / (ops / ns)")
ggsave('array_ops_throughput.svg', plot = img, width = 2 + 3 * length(files), height = 40)
