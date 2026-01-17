suppressPackageStartupMessages({
  library(readr)
})

#' Performs a hypothesis test (t-test, Mann-Whitney U, or correlation) between two variables.
#'
#' @param path Path to the input CSV file.
#' @param test_type The type of test to perform: "t_test", "mann_whitney_u", or "correlation".
#' @param var1 The name of the first variable (column).
#' @param var2 The name of the second variable (column), required for all tests.
#' @return A list containing the test results, such as method, statistic, p-value, etc.
tool_hypothesis_test <- function(path, test_type, var1, var2) {
  df <- readr::read_csv(path, show_col_types = FALSE)
  stopifnot(var1 %in% names(df), !is.null(var2), var2 %in% names(df))

  res <- switch(test_type,
    "t_test" = {
      res <- stats::t.test(df[[var1]], df[[var2]])
      list(method = res$method, statistic = unname(res$statistic), p_value = res$p.value, conf_int = unname(res$conf.int))
    },
    "mann_whitney_u" = {
      res <- stats::wilcox.test(df[[var1]], df[[var2]])
      list(method = res$method, statistic = unname(res$statistic), p_value = res$p.value)
    },
    "correlation" = {
      r <- suppressWarnings(stats::cor(df[[var1]], df[[var2]], use = "complete.obs"))
      list(method = "Pearson's product-moment correlation", r = r)
    },
    stop("unsupported test_type. Must be one of 't_test', 'mann_whitney_u', 'correlation'")
  )
  return(res)
}
