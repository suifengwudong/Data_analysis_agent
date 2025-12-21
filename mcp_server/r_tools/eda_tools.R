suppressPackageStartupMessages({library(readr); library(dplyr)})

#' Performs basic exploratory data analysis on a CSV file.
#'
#' @param path Path to the input CSV file.
#' @param variables Optional vector of column names to analyze. If NULL, all columns are included.
#' @return A list containing data shape, column names, NA counts, and a summary of numeric columns.
tool_eda <- function(path, variables = NULL) {
  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)
  if (!is.null(variables) && length(variables) > 0) {
    keep <- variables[variables %in% names(df)]
    if (length(keep) > 0) df <- df[, keep, drop = FALSE]
  }
  num_df <- dplyr::select(df, where(is.numeric))
  list(
    shape = c(nrow(df), ncol(df)),
    columns = names(df),
    na_count = colSums(is.na(df)),
    summary_num = if (ncol(num_df) > 0) summary(num_df) else "no numeric columns"
  )
}
