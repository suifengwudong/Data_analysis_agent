suppressPackageStartupMessages({
  library(stats)
})

#' Performs a Wilcoxon Rank Sum (Mann-Whitney U) Test
#'
#' @param path Path to the input CSV file
#' @param formula_str Formula string (e.g. "mass_g ~ fall")
#' @param paired Logical, whether to perform a paired test
#' @param alternative String, one of "two.sided", "less", "greater"
#' @return A list containing test statistics
tool_wilcox_test <- function(path, formula_str, paired = FALSE, alternative = "two.sided") {
  # Load data using utility
  df <- load_and_filter_data(path)
  
  # Align formula variables (robustness)
  formula_str <- align_formula_vars(formula_str, colnames(df))
  formula <- as.formula(formula_str)
  
  if (paired) {
    stop("The formula interface for Wilcoxon test does not support paired samples. Please use independent samples or a different method.")
  }

  # Perform Test (Do not pass 'paired' argument to formula method)
  res <- stats::wilcox.test(formula, data = df, alternative = alternative)
  
  list(
    method = res$method,
    statistic = res$statistic[[1]],
    p_value = res$p.value
  )
}
