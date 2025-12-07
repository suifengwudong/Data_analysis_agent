suppressPackageStartupMessages({library(readr); library(ggplot2)})

tool_visualize <- function(path, plot_type, x_var, y_var = NULL, output_path = "plot.png") {
  df <- readr::read_csv(path, show_col_types = FALSE)
  stopifnot(x_var %in% names(df))
  p <- switch(plot_type,
    "scatter"   = { stopifnot(!is.null(y_var), y_var %in% names(df));
                    ggplot(df, aes(.data[[x_var]], .data[[y_var]])) + geom_point() },
    "histogram" = ggplot(df, aes(.data[[x_var]])) + geom_histogram(bins = 30),
    "boxplot"   = ggplot(df, aes(x = 1, y = .data[[x_var]])) + geom_boxplot(),
    stop("unsupported plot_type")
  )
  ggsave(output_path, p, width = 8, height = 6, dpi = 150)
  list(output = normalizePath(output_path))
}
