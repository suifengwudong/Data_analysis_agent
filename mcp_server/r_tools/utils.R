suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(janitor)
  library(rlang)
})

#' Load data from CSV and optionally filter it using an R expression
#'
#' @param path Path to the CSV file
#' @param filter_expr Optional R expression string for filtering (e.g., "mass_g > 100")
#' @return A tibble containing the (filtered) data
load_and_filter_data <- function(path, filter_expr = NULL) {
  if (!file.exists(path)) {
    stop(paste("File not found:", path))
  }
  
  df <- readr::read_csv(path, show_col_types = FALSE)
  
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    # Use rlang::parse_expr to handle the string expression safely
    tryCatch({
      df <- df %>% dplyr::filter(!!rlang::parse_expr(filter_expr))
    }, error = function(e) {
      stop(paste("Error filtering data with expression:", filter_expr, "\nDetails:", e$message))
    })
  }
  
  return(df)
}

#' Helper function to align formula variables with actual column names
#' This function makes tools robust to inconsistencies in column naming (e.g. 'mass (g)' vs 'mass_g')
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
    name <- gsub("_+", "_", name)
    name <- gsub("^_|_$", "", name)
    name
  }

  cleaned_df_colnames <- clean_name(df_colnames)
  name_map <- setNames(df_colnames, cleaned_df_colnames)

  # Extract raw variable names using regex to avoid all.vars() issues with special chars
  raw_formula_vars <- unique(trimws(strsplit(formula_str, "[~+*:]")[[1]]))
  raw_formula_vars <- raw_formula_vars[raw_formula_vars != ""]

  cleaned_formula_vars <- clean_name(raw_formula_vars)

  # Check for unmatched variables
  unmatched_cleaned_vars <- setdiff(cleaned_formula_vars, names(name_map))
  if (length(unmatched_cleaned_vars) > 0) {
    original_unmatched <- raw_formula_vars[match(unmatched_cleaned_vars, cleaned_formula_vars)]
    # Don't stop here strictly, as interaction terms or I() might be used, but warn or try best effort. 
    # For now, we assume simple variables.
    # stop(paste("The following variables in the formula do not match:", paste(original_unmatched, collapse = ", ")))
  }

  # Create replacement map
  replacement_map <- list()
  for (i in seq_along(raw_formula_vars)) {
    raw_var <- raw_formula_vars[i]
    cleaned_var <- cleaned_formula_vars[i]
    if (cleaned_var %in% names(name_map)) {
        original_df_col <- name_map[cleaned_var]
        replacement_map[[raw_var]] <- backtick(original_df_col)
    }
  }

  # Rebuild formula string
  new_formula_str <- formula_str
  sorted_vars <- names(replacement_map)[order(nchar(names(replacement_map)), decreasing = TRUE)]
  
  # Simple polyfill for preg_quote logic since R regex doesn't have it built-in directly
  escape_regex <- function(s) {
      gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", s)
  }

  for (var in sorted_vars) {
    pattern <- paste0("\\b", escape_regex(var), "\\b")
    replacement <- replacement_map[[var]]
    new_formula_str <- gsub(pattern, replacement, new_formula_str, perl = TRUE)
  }

  return(new_formula_str)
}
