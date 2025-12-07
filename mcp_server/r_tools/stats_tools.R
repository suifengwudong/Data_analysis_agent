suppressPackageStartupMessages({library(readr)})

tool_hypothesis_test <- function(path, test_type, var1, var2 = NULL) {
  df <- readr::read_csv(path, show_col_types = FALSE)
  stopifnot(var1 %in% names(df))
  if (test_type == "t_test") {
    stopifnot(!is.null(var2), var2 %in% names(df))
    res <- stats::t.test(df[[var1]], df[[var2]])
    list(method = res$method, statistic = unname(res$statistic),
         p_value = res$p.value, conf_int = unname(res$conf.int))
  } else if (test_type == "correlation") {
    stopifnot(!is.null(var2), var2 %in% names(df))
    r <- suppressWarnings(stats::cor(df[[var1]], df[[var2]], use = "complete.obs"))
    list(method = "pearson", r = r)
  } else {
    stop("unsupported test_type")
  }
}
