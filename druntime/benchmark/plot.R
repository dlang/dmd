# compile master dmd&druntime&phobos
# ./runbench -v > baseline.txt
# compile feature branch dmd&druntime&phobos
# ./runbench -v > feature.txt
# optionally compile variation of feature branch dmd&druntime&phobos
# ./runbench -v > feature_variation.txt
# Rscript --vanilla plot.R baseline.txt feature.txt feature_variation.txt
library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)

args <- commandArgs(trailingOnly=T)

readResults <- function(path) {
    lines <- readLines(path)
    run_pattern <- "^RUN ([^ ]+)\\s+([0-9.]+) s$"
    gc_pattern <- "^RUN ([^ ]+)\\s+([0-9.]+) s,\\s*([0-9]+) MB,\\s* ([0-9]+) GC\\s*([0-9]+) ms, Pauses\\s*([0-9]+) ms.* <\\s*([0-9]+) ms$"
    if (any(grepl(gc_pattern, lines))) {
        matches <- grepl(gc_pattern, lines)
        values <- sub(gc_pattern, "\\1,\\2,\\3,\\4,\\5,\\6,\\7", lines)
        names <- c("bench", "time_s", "gc.heap.max", "gc.num_collections", "gc.time.total", "gc.pause_time.total", "gc.pause_time.max")
    } else {
        matches <- grepl(run_pattern, lines)
        values <- sub(run_pattern, "\\1,\\2", lines)
        names <- c("bench", "time_s")
    }
    values <- strsplit(values[matches], split=',')
    df <- as.data.frame(do.call("rbind", values), stringsAsFactors = FALSE)
    colnames(df) <- names
    df[2:ncol(df)] <- lapply(df[2:ncol(df)], as.numeric)
    df$testee <- path
    tbl_df(df)
}
result <- do.call("rbind", lapply(args, readResults))
result.plot <- gather(result, metric, value, -bench, -testee)

p <- ggplot(result.plot, aes(x=bench, y=value, color=testee)) +
    geom_boxplot(position = "dodge", lwd = 0.25, outlier.size = 0.5, outlier.shape = 1, outlier.alpha = 0.5) +
    facet_grid(metric ~ ., scales="free_y") +
    scale_y_continuous(trans=log1p_trans()) +
    theme(axis.text.x=element_text(angle=45, hjust=1, vjust=1))

ggsave("runbench.png", p, w=12, h=6 * (ncol(result) - 2))
