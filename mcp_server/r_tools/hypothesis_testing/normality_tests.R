suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(moments)
})

#' Performs a Shapiro-Wilk normality test and calculates skewness and kurtosis.
#'
#' @param path Path to the input CSV file.
#' @param var The name of the variable (column) to test for normality.
#' @param filter_expr An optional R expression string to filter the data before testing.
#' @param transform An optional transformation to apply to the variable before testing (e.g., "log10", "sqrt").
#' @return A list containing the test method, statistic (W), p-value, skewness, and kurtosis.
tool_normality_test <- function(path,
                                var,
                                filter_expr = NULL,
                                transform = NULL) {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Apply filtering if filter_expr is provided
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    df <- dplyr::filter(df, !!rlang::parse_expr(filter_expr))
  }

  stopifnot(var %in% names(df))

  # Extract the vector for testing
  x <- df[[var]]

  # Apply transformation if specified
  if (!is.null(transform) && nzchar(transform)) {
    transform_func <- match.fun(transform)
    x <- transform_func(x)
  }

  # Remove NAs, Infs, and -Infs
  x <- x[is.finite(x)]

  # Check if there are enough data points for the test
  if (length(x) < 3) {
    stop("Not enough data points to perform the normality test after cleaning.")
  }

  # Perform the Shapiro-Wilk test
  res <- stats::shapiro.test(x)

  # Calculate skewness and kurtosis
  skew <- moments::skewness(x)
  kurt <- moments::kurtosis(x)

  list(
    method = res$method,
    statistic = res$statistic,
    p_value = res$p.value,
    skewness = skew,
    kurtosis = kurt
  )
}

#' Performs a Kolmogorov-Smirnov (K-S) normality test.
#'
#' @param path Path to the input CSV file.
#' @param var The name of the variable (column) to test for normality.
#' @param filter_expr An optional R expression string to filter the data before testing.
#' @param transform An optional transformation to apply to the variable before testing (e.g., "log10", "sqrt").
#' @return A list containing the test method, statistic (D), and p-value.
tool_ks_test <- function(path,
                         var,
                         filter_expr = NULL,
                         transform = NULL) {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Apply filtering if filter_expr is provided
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    df <- dplyr::filter(df, !!rlang::parse_expr(filter_expr))
  }

  stopifnot(var %in% names(df))

  # Extract the vector for testing
  x <- df[[var]]

  # Apply transformation if specified
  if (!is.null(transform) && nzchar(transform)) {
    transform_func <- match.fun(transform)
    x <- transform_func(x)
  }

  # Remove NAs, Infs, and -Infs
  x <- x[is.finite(x)]

  # Check if there are enough data points for the test
  if (length(x) < 2) {
    stop("Not enough data points to perform the K-S test after cleaning.")
  }

  # Perform the K-S test against a normal distribution
  # We need to standardize the data for this test
  x_scaled <- scale(x)
  res <- stats::ks.test(x_scaled, "pnorm")

  list(
    method = res$method,
    statistic = res$statistic,
    p_value = res$p.value
  )
}
