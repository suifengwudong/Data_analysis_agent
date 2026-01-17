suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(janitor)
})

#' Cleans a dataset by standardizing column names, removing NAs, zeros, and filtering by a numeric range.
#'
#' @param path Path to the input CSV file.
#' @param output_path Path to save the cleaned CSV file.
#' @param clean_colnames Boolean, if TRUE (default), standardizes column names to be R-friendly (e.g., 'mass (g)' becomes 'mass_g').
#' @param na_cols Optional vector of column names. Rows with NAs in any of these columns will be removed.
#' @param zero_cols Optional vector of column names. Rows with a value of 0 in any of these columns will be removed.
#' @param filter_col Optional column name for numeric range filtering.
#' @param min_val Optional minimum value for the range filter (inclusive).
#' @param max_val Optional maximum value for the range filter (inclusive).
#' @return A list containing the path to the cleaned data, the number of rows removed,
#'         the final shape of the data, and a map of original to new column names.
tool_clean_data <- function(path,
                            output_path,
                            clean_colnames = TRUE,
                            na_cols = NULL,
                            zero_cols = NULL,
                            filter_col = NULL,
                            min_val = NULL,
                            max_val = NULL) {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)
  initial_rows <- nrow(df)
  original_names <- names(df)
  new_names <- original_names

  # Standardize column names if requested
  if (clean_colnames) {
    df <- janitor::clean_names(df)
    new_names <- names(df)
  }
  
  # Create a mapping of original names to new names
  # It will only contain names that have actually changed.
  column_map <- setNames(new_names, original_names)
  column_map <- column_map[original_names != new_names]

  # If na_cols are provided, they might be using original names.
  # We need to convert them to the new, cleaned names before using them.
  if (!is.null(na_cols) && length(na_cols) > 0) {
      # Clean the provided na_cols to match the new column names in the dataframe
      cleaned_na_cols <- janitor::make_clean_names(na_cols)
      valid_na_cols <- cleaned_na_cols[cleaned_na_cols %in% names(df)]
      if (length(valid_na_cols) > 0) {
          df <- tidyr::drop_na(df, all_of(valid_na_cols))
      }
  }

  # Same for zero_cols
  if (!is.null(zero_cols) && length(zero_cols) > 0) {
    cleaned_zero_cols <- janitor::make_clean_names(zero_cols)
    for (col in cleaned_zero_cols) {
      if (col %in% names(df) && is.numeric(df[[col]])) {
        df <- dplyr::filter(df, .data[[col]] != 0)
      }
    }
  }

  # Same for filter_col
  if (!is.null(filter_col) && !is.null(min_val) && !is.null(max_val)) {
    cleaned_filter_col <- janitor::make_clean_names(filter_col)
    if (cleaned_filter_col %in% names(df) && is.numeric(df[[cleaned_filter_col]])) {
      df <- dplyr::filter(df, .data[[cleaned_filter_col]] >= min_val & .data[[cleaned_filter_col]] <= max_val)
    }
  }

  # Save the cleaned data
  readr::write_csv(df, output_path)

  final_rows <- nrow(df)
  rows_removed <- initial_rows - final_rows

  list(
    cleaned_data_path = normalizePath(output_path),
    rows_removed = rows_removed,
    final_shape = c(final_rows, ncol(df)),
    column_map = column_map
  )
}
