suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(broom)
  library(ggplot2)
  library(glmnet)
})

# Helper function to align formula variables with actual column names
# This function makes the tool robust to inconsistencies in column naming.
align_formula_vars <- function(formula_str, df_colnames) {
  # Backtick helper
  backtick <- function(x) {
    ifelse(grepl("[^a-zA-Z0-9_.]", x) & !grepl("^`.*`$", x), paste0("`", x, "`"), x)
  }

  # Simplified janitor::clean_names logic
  clean_name <- function(name) {
    name <- tolower(name)
    name <- gsub("'", "", name)
    name <- gsub("%", "percent", name)
    name <- gsub("[^a-z0-9_]+", "_", name)
    name <- gsub("^_|_$", "", name)
    name
  }

  # Create a map from cleaned df column names to original df column names
  cleaned_df_colnames <- clean_name(df_colnames)
  name_map <- setNames(df_colnames, cleaned_df_colnames)

  # Extract raw variable names from formula string using regex
  # This avoids issues with all.vars() on special characters
  raw_formula_vars <- unique(trimws(strsplit(formula_str, "[~+*:]")[[1]]))
  raw_formula_vars <- raw_formula_vars[raw_formula_vars != ""]

  # Clean the extracted raw formula variables
  cleaned_formula_vars <- clean_name(raw_formula_vars)

  # Check for variables that can't be matched
  unmatched_cleaned_vars <- setdiff(cleaned_formula_vars, names(name_map))
  if (length(unmatched_cleaned_vars) > 0) {
    # Find the original raw var name that corresponds to the unmatched cleaned var
    original_unmatched <- raw_formula_vars[match(unmatched_cleaned_vars, cleaned_formula_vars)]
    stop(paste("The following variables in the formula do not match any column in the data:", paste(original_unmatched, collapse = ", ")))
  }

  # Create a map from raw formula vars to backticked original df colnames
  # e.g., "mass (g)" -> "`mass (g)`"
  # e.g., "year" -> "year"
  replacement_map <- list()
  for (i in seq_along(raw_formula_vars)) {
    raw_var <- raw_formula_vars[i]
    cleaned_var <- cleaned_formula_vars[i]
    original_df_col <- name_map[cleaned_var]
    replacement_map[[raw_var]] <- backtick(original_df_col)
  }

  # Rebuild the formula string by replacing raw vars with their backticked versions
  new_formula_str <- formula_str
  # Sort keys by length descending to replace longer matches first (e.g., "var10" before "var1")
  sorted_vars <- names(replacement_map)[order(nchar(names(replacement_map)), decreasing = TRUE)]
  
  for (var in sorted_vars) {
    # Use word boundaries to avoid replacing parts of other words
    pattern <- paste0("\\b", preg_quote(var), "\\b")
    replacement <- replacement_map[[var]]
    new_formula_str <- gsub(pattern, replacement, new_formula_str, perl = TRUE)
  }

  return(new_formula_str)
}

# A simple polyfill for base::preg_quote if not available (older R versions)
preg_quote <- function(str) {
  gsub("([.^$*+?()[{\\|])", "\\\\\\1", str)
}

#' Fits a Generalized Linear Model (GLM) and generates diagnostic plots.
#'
#' @param path Path to the input CSV file.
#' @param formula_str An R formula string, e.g., "y ~ x1 + x2".
#' @param family The error distribution and link function to be used in the model.
#'   Examples: "gaussian" for Linear Regression, "binomial" for Logistic Regression.
#' @param out_dir Path to the directory to save diagnostic plots.
#' @return A list containing the tidy model data, paths to diagnostic plots, and the model summary.
tool_glm <- function(path, formula_str, family = "gaussian", out_dir = "glm_diagnostics") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Align formula variables with dataframe column names
  formula_str <- align_formula_vars(formula_str, colnames(df))

  # Create output directory if it doesn't exist
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  # Fit the model
  model <- glm(as.formula(formula_str), data = df, family = family)
  
  # --- Save Model Summary ---
  summary_path <- file.path(out_dir, "model_summary.txt")
  sink(summary_path)
  print(summary(model))
  sink()

  # --- Generate and Save Diagnostic Plots ---
  plot_paths <- list()
  
  # 1. Residuals vs. Fitted
  p1_path <- file.path(out_dir, "residuals_vs_fitted.png")
  png(p1_path, width = 800, height = 600)
  plot(model, which = 1)
  dev.off()
  plot_paths$residuals_vs_fitted <- normalizePath(p1_path)

  # 2. Normal Q-Q
  p2_path <- file.path(out_dir, "normal_qq.png")
  png(p2_path, width = 800, height = 600)
  plot(model, which = 2)
  dev.off()
  plot_paths$normal_qq <- normalizePath(p2_path)

  # 3. Scale-Location
  p3_path <- file.path(out_dir, "scale_location.png")
  png(p3_path, width = 800, height = 600)
  plot(model, which = 3)
  dev.off()
  plot_paths$scale_location <- normalizePath(p3_path)

  # 4. Residuals vs. Leverage
  p4_path <- file.path(out_dir, "residuals_vs_leverage.png")
  png(p4_path, width = 800, height = 600)
  plot(model, which = 5)
  dev.off()
  plot_paths$residuals_vs_leverage <- normalizePath(p4_path)

  # Tidy the model output and return
  
  # Read summary content to returned list
  summary_content <- paste(readLines(summary_path), collapse = "\n")

  list(
    model_tidy = broom::tidy(model),
    summary_path = normalizePath(summary_path),
    model_summary = summary_content,
    plot_paths = plot_paths
  )
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
#' @return A list containing the best lambda, non-zero coefficients, and paths to the plot and coefficients CSV.
tool_regularized_regression <- function(path, formula_str, model_type = "lasso", alpha = 1.0, family = "gaussian", out_path = "cv_plot.png") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Align formula variables with dataframe column names
  formula_str <- align_formula_vars(formula_str, colnames(df))

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

  # Filter for non-zero coefficients
  non_zero_coefs <- tidy_coefs %>%
    filter(estimate != 0) %>%
    select(term, estimate) %>%
    arrange(desc(abs(estimate)))
    
  # Save coefficients to a CSV file
  coef_out_path <- sub("\\.png$", "_coefficients.csv", out_path)
  readr::write_csv(non_zero_coefs, coef_out_path)

  list(
    best_lambda = best_lambda,
    coefficients = non_zero_coefs,
    plot_path = normalizePath(out_path),
    coefficients_path = normalizePath(coef_out_path)
  )
}
