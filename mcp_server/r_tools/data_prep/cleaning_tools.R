suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
})

#' Cleans a dataset by removing NAs, zeros, and filtering by a numeric range.
#'
#' @param path Path to the input CSV file.
#' @param output_path Path to save the cleaned CSV file.
#' @param na_cols Optional vector of column names. Rows with NAs in any of these columns will be removed.
#' @param zero_cols Optional vector of column names. Rows with a value of 0 in any of these columns will be removed.
#' @param filter_col Optional column name for numeric range filtering.
#' @param min_val Optional minimum value for the range filter (inclusive).
#' @param max_val Optional maximum value for the range filter (inclusive).
#' @return A list containing the path to the cleaned data and the number of rows removed.
tool_clean_data <- function(path,
                            output_path,
                            na_cols = NULL,
                            zero_cols = NULL,
                            filter_col = NULL,
                            min_val = NULL,
                            max_val = NULL) {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)
  initial_rows <- nrow(df)

  # Remove rows with NAs in specified columns if na_cols is provided
  if (!is.null(na_cols) && length(na_cols) > 0) {
    valid_na_cols <- na_cols[na_cols %in% names(df)]
    if (length(valid_na_cols) > 0) {
      df <- tidyr::drop_na(df, all_of(valid_na_cols))
    }
  }

  # Remove rows with 0 in specified columns if zero_cols is provided
  if (!is.null(zero_cols) && length(zero_cols) > 0) {
    for (col in zero_cols) {
      if (col %in% names(df) && is.numeric(df[[col]])) {
        df <- dplyr::filter(df, .data[[col]] != 0)
      }
    }
  }

  # Filter rows based on a numeric range if all filter parameters are provided
  if (!is.null(filter_col) && !is.null(min_val) && !is.null(max_val)) {
    if (filter_col %in% names(df) && is.numeric(df[[filter_col]])) {
      df <- dplyr::filter(df, .data[[filter_col]] >= min_val & .data[[filter_col]] <= max_val)
    }
  }

  # Save the cleaned data
  readr::write_csv(df, output_path)

  final_rows <- nrow(df)
  rows_removed <- initial_rows - final_rows

  list(
    cleaned_data_path = normalizePath(output_path),
    rows_removed = rows_removed,
    final_shape = c(final_rows, ncol(df))
  )
}
