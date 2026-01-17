suppressPackageStartupMessages({
  library(readr)
  library(broom)
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

#' Performs ANOVA and saves the summary and diagnostic plots.
#'
#' @param path Path to the input CSV file.
#' @param formula_str An R formula string for the ANOVA model, e.g., "dependent_var ~ factor1 * factor2".
#' @param out_dir Path to the directory to save the summary and plots.
#' @return A list containing the tidy ANOVA table, the path to the summary file, and paths to diagnostic plots.
tool_anova <- function(path, formula_str, out_dir = "anova_diagnostics") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Align formula variables with dataframe column names
  formula_str <- align_formula_vars(formula_str, colnames(df))

  # Create output directory if it doesn't exist
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  # Fit the ANOVA model
  aov_model <- aov(as.formula(formula_str), data = df)

  # --- Save Model Summary ---
  summary_path <- file.path(out_dir, "anova_summary.txt")
  sink(summary_path)
  print(summary(aov_model))
  sink()
  
  # --- Generate and Save Diagnostic Plots ---
  plot_paths <- list()
  
  # 1. Residuals vs. Fitted
  p1_path <- file.path(out_dir, "residuals_vs_fitted.png")
  png(p1_path, width = 800, height = 600)
  plot(aov_model, which = 1)
  dev.off()
  plot_paths$residuals_vs_fitted <- normalizePath(p1_path)

  # 2. Normal Q-Q
  p2_path <- file.path(out_dir, "normal_qq.png")
  png(p2_path, width = 800, height = 600)
  plot(aov_model, which = 2)
  dev.off()
  plot_paths$normal_qq <- normalizePath(p2_path)

  # Tidy the model output and return
  list(
    anova_tidy = broom::tidy(aov_model),
    summary_path = normalizePath(summary_path),
    plot_paths = plot_paths
  )
}
