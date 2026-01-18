suppressPackageStartupMessages({
  library(stats)
  library(broom)
})

#' Performs a Student's t-test or Welch's t-test
#'
#' @param path Path to the input CSV file
#' @param formula_str Formula string (e.g. "mass_g ~ fall")
#' @param paired Logical, whether to perform a paired t-test
#' @param var_equal Logical, whether to assume equal variances (if TRUE, performs Student's t-test; if FALSE, Welch's)
#' @param alternative String, one of "two.sided", "less", "greater"
#' @return A list containing test statistics
tool_t_test <- function(path, formula_str, paired = FALSE, var_equal = FALSE, alternative = "two.sided") {
  # Load data using utility
  df <- load_and_filter_data(path)
  
  # Align formula variables (robustness)
  formula_str <- align_formula_vars(formula_str, colnames(df))
  formula <- as.formula(formula_str)
  
  if (paired) {
    stop("The formula interface for t-test does not support paired samples. Please use independent samples or a different method.")
  }

  # Perform Test (Do not pass 'paired' argument)
  res <- stats::t.test(formula, data = df, var.equal = var_equal, alternative = alternative)
  
  list(
    method = res$method,
    statistic = res$statistic[[1]],
    p_value = res$p.value,
    conf_int_lower = if (!is.null(res$conf.int)) res$conf.int[1] else NULL,
    conf_int_upper = if (!is.null(res$conf.int)) res$conf.int[2] else NULL,
    estimate = if (!is.null(res$estimate)) as.list(res$estimate) else NULL
  )
}
