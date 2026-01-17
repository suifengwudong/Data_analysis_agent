suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(broom)
  library(ggplot2)
  library(glmnet)
})

#' Fits a Generalized Linear Model (GLM) and generates diagnostic plots.
#'
#' @param path Path to the input CSV file.
#' @param formula_str An R formula string, e.g., "y ~ x1 + x2".
#' @param family The error distribution and link function to be used in the model.
#'   Examples: "gaussian" for Linear Regression, "binomial" for Logistic Regression.
#' @param out_dir Path to the directory to save diagnostic plots.
#' @return A tidy data frame of the model's coefficients and summary statistics.
tool_glm <- function(path, formula_str, family = "gaussian", out_dir = "glm_diagnostics") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Create output directory if it doesn't exist
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  # Fit the model
  model <- glm(as.formula(formula_str), data = df, family = family)

  # --- Generate and Save Diagnostic Plots ---

  # 1. Residuals vs. Fitted
  png(file.path(out_dir, "residuals_vs_fitted.png"), width = 800, height = 600)
  plot(model, which = 1)
  dev.off()

  # 2. Normal Q-Q
  png(file.path(out_dir, "normal_qq.png"), width = 800, height = 600)
  plot(model, which = 2)
  dev.off()

  # 3. Scale-Location
  png(file.path(out_dir, "scale_location.png"), width = 800, height = 600)
  plot(model, which = 3)
  dev.off()

  # 4. Residuals vs. Leverage
  png(file.path(out_dir, "residuals_vs_leverage.png"), width = 800, height = 600)
  plot(model, which = 5)
  dev.off()

  # Tidy the model output and return
  broom::tidy(model)
}


#' Performs regularized regression (Lasso, Ridge, or Elastic Net) using glmnet.
#'
#' @param path Path to the input CSV file.
#' @param formula_str An R formula string, e.g., "y ~ x1 + x2".
#' @param model_type The type of regularization: "lasso", "ridge", or "elastic_net".
#' @param alpha The elasticnet mixing parameter, with 0 <= alpha <= 1.
#'   alpha=1 is lasso (default), alpha=0 is ridge. Ignored if model_type is "lasso" or "ridge".
#' @param family The model family, e.g., "gaussian" for linear, "binomial" for logistic.
#' @param out_path Path to save the cross-validation plot.
#' @return A data frame of the non-zero coefficients at the optimal lambda.
tool_regularized_regression <- function(path, formula_str, model_type = "lasso", alpha = 1.0, family = "gaussian", out_path = "cv_plot.png") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Prepare data based on formula
  formula <- as.formula(formula_str)
  mf <- model.frame(formula, data = df, na.action = na.omit)
  x <- model.matrix(formula, data = mf)[, -1] # Predictor matrix, remove intercept
  y <- model.response(mf) # Response variable

  # Set alpha based on model_type
  current_alpha <- switch(model_type,
                          "lasso" = 1,
                          "ridge" = 0,
                          "elastic_net" = alpha)

  # Perform cross-validation to find the best lambda
  set.seed(42)
  cv_fit <- cv.glmnet(x, y, family = family, alpha = current_alpha)

  # Save the cross-validation plot
  png(out_path, width = 800, height = 600)
  plot(cv_fit)
  dev.off()

  # Get coefficients at the best lambda (lambda.min)
  best_lambda <- cv_fit$lambda.min
  coefs <- coef(cv_fit, s = best_lambda)

  # Convert to a tidy data frame
  tidy_coefs <- as.data.frame(as.matrix(coefs))
  tidy_coefs$term <- rownames(tidy_coefs)
  names(tidy_coefs)[1] <- "estimate"

  # Filter for non-zero coefficients and return
  non_zero_coefs <- tidy_coefs %>%
    filter(estimate != 0) %>%
    select(term, estimate) %>%
    arrange(desc(abs(estimate)))

  list(
    best_lambda = best_lambda,
    coefficients = non_zero_coefs,
    plot_path = normalizePath(out_path)
  )
}
