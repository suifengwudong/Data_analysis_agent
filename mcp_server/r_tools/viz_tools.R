suppressPackageStartupMessages({library(readr); library(ggplot2); library(dplyr)})

tool_visualize <- function(path, plot_type, x_var, y_var = NULL, filter_expr = NULL, x_trans = NULL, y_trans = NULL, output_path = "plot.png") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Apply filtering if filter_expr is provided
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    df <- dplyr::filter(df, !!rlang::parse_expr(filter_expr))
  }

  stopifnot(x_var %in% names(df))
  p <- switch(plot_type,
    "scatter"   = { stopifnot(!is.null(y_var), y_var %in% names(df));
                    ggplot(df, aes(.data[[x_var]], .data[[y_var]])) + geom_point() },
    "histogram" = ggplot(df, aes(.data[[x_var]])) + geom_histogram(bins = 30),
    "boxplot"   = ggplot(df, aes(x = 1, y = .data[[x_var]])) + geom_boxplot(),
    stop("unsupported plot_type")
  )

  # Apply transformations if specified
  if (!is.null(x_trans) && nzchar(x_trans)) {
    p <- p + scale_x_continuous(trans = x_trans)
  }
  if (!is.null(y_trans) && nzchar(y_trans)) {
    p <- p + scale_y_continuous(trans = y_trans)
  }

  ggsave(output_path, p, width = 8, height = 6, dpi = 150)
  list(output = normalizePath(output_path))
}
