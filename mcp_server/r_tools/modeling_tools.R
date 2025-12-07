suppressPackageStartupMessages({library(readr); library(broom)})

tool_linear_model <- function(path, formula_str, out_dir="outputs") {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  df  <- readr::read_csv(path, show_col_types = FALSE)
  fit <- stats::lm(stats::as.formula(formula_str), data = df)
  png(file.path(out_dir, "lm_diagnostics.png"), width = 1200, height = 900)
  par(mfrow=c(2,2)); plot(fit); dev.off()
  list(
    glance = broom::glance(fit),
    tidy   = broom::tidy(fit),
    diag_plot = normalizePath(file.path(out_dir, "lm_diagnostics.png"))
  )
}
