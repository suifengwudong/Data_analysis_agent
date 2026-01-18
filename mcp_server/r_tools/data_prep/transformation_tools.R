suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

#' Applies a mathematical transformation to specified columns in a dataset.
#'
#' @param path Path to the input CSV file.
#' @param output_path Path to save the transformed CSV file.
#' @param vars A vector of column names to be transformed.
#' @param method The transformation method to apply. Supported methods: "log10", "log", "sqrt".
#' @param add_constant An optional small constant to add to the variable before transformation,
#'   useful to avoid issues like log(0). Default is 0.
#' @return A list containing the path to the transformed data.
tool_transform_variable <- function(path,
                                    output_path,
                                    vars,
                                    method = "log10",
                                    add_constant = 0) {
  
  # Load data using utility (no filtering parameter here as transform acts on whole file usually, 
  # or we could add filter_expr if needed, but standard is transform then filter)
  # Actually, load_and_filter_data is nice for consistency.
  df <- load_and_filter_data(path)

  # Validate method
  supported_methods <- c("log10", "log", "sqrt")
  if (!method %in% supported_methods) {
    stop(paste("Unsupported transformation method. Please use one of:", paste(supported_methods, collapse = ", ")))
  }
  transform_func <- match.fun(method)

  # Apply transformation to each specified variable
  for (var in vars) {
    if (!var %in% names(df)) {
      warning(paste("Variable '", var, "' not found in the dataset. Skipping.", sep = ""))
      next
    }
    if (!is.numeric(df[[var]])) {
      warning(paste("Variable '", var, "' is not numeric. Skipping.", sep = ""))
      next
    }
    
    # Create a new column name for the transformed variable
    # Use clean_name from utils functionality logic (inline here to avoid scoping issues if utils not loaded globally correctly)
    clean_base_var <- tolower(gsub("[^a-zA-Z0-9_]+", "_", var))
    clean_base_var <- gsub("_+", "_", clean_base_var)
    clean_base_var <- gsub("^_|_$", "", clean_base_var)
    
    new_var_name <- paste0(clean_base_var, "_", method)
    
    # Apply transformation
    df <- df %>%
      mutate(!!new_var_name := transform_func(.data[[var]] + add_constant))
  }

  # Save the transformed data
  readr::write_csv(df, output_path)

  list(
    transformed_data_path = normalizePath(output_path)
  )
}

#' Calculates a moving average (rolling mean) for a specified column.
#'
#' @param path Path to the input CSV file.
#' @param output_path Path to save the transformed CSV file.
#' @param time_col Name of the column representing time (for sorting).
#' @param value_col Name of the numeric column to calculate the moving average for.
#' @param window_size Integer, the size of the moving window.
#' @return A list containing the path to the transformed data.
tool_moving_average <- function(path,
                                output_path,
                                time_col,
                                value_col,
                                window_size = 5) {
  
  df <- load_and_filter_data(path)
  
  stopifnot(time_col %in% names(df), value_col %in% names(df))
  stopifnot(is.numeric(df[[value_col]]))
  
  # Ensure zoo is available for rollmean, otherwise implement manually or use simple filter
  # Using filter/kernel stats::filter
  
  # Sort by time
  df <- df %>% arrange(.data[[time_col]])
  
  # Calculate moving average
  # stats::filter is standard. Sides=1 (past values only) or 2 (centered)? 
  # Usually moving average implies centered or trailing. Let's assume centered (sides=2) for smoothing, 
  # or filtering past data (sides=1). Let's use sides=2 (centered) as default for smoothing visualization.
  # But simple moving average often implies sides=1 (trailing). 
  # Let's stick to standard specialized package free implementation if possible or use stats.
  
  ma_col_name <- paste0(value_col, "_ma", window_size)
  
  # Using data.table::frollmean or zoo::rollmean is best, but to minimize dependencies let's use stats::filter
  # sides = 1 means convolution filters past values. sides = 2 filters centered.
  # Let's use centered for general smoothing.
  
  x <- df[[value_col]]
  filt <- rep(1/window_size, window_size)
  
  # sides=2 (centered). If window_size is even, it's slightly off-center left.
  y <- stats::filter(x, filt, sides = 2)
  
  df[[ma_col_name]] <- as.numeric(y)
  
  readr::write_csv(df, output_path)
  
  list(
    transformed_data_path = normalizePath(output_path)
  )
}

