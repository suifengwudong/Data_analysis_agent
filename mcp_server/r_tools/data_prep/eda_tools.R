suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

#' Performs basic exploratory data analysis on a CSV file.
#'
#' @param path Path to the input CSV file.
#' @param variables Optional vector of column names to analyze. If NULL, all columns are included.
#' @return A list containing data shape, column names, NA counts, and a summary of numeric columns.
tool_eda <- function(path, variables = NULL) {
  # Load data using utility (filtering is not usually needed for basic EDA but consistency is good)
  df <- load_and_filter_data(path)

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

#' Performs a correlation analysis between two variables.
#'
#' @param path Path to the input CSV file.
#' @param var1 The name of the first variable (column).
#' @param var2 The name of the second variable (column).
#' @param method Correlation method: "pearson", "kendall", "spearman".
#' @return A list containing the correlation coefficient and method used.
tool_correlation <- function(path, var1, var2, method = "pearson") {
  df <- load_and_filter_data(path)

  stopifnot(var1 %in% names(df), var2 %in% names(df))

  if (!is.numeric(df[[var1]]) || !is.numeric(df[[var2]])) {
    stop("Both variables must be numeric for correlation analysis.")
  }

  r <- suppressWarnings(stats::cor(df[[var1]], df[[var2]], use = "complete.obs", method = method))

  list(
    method = paste(method, "correlation"),
    correlation = r
  )
}
