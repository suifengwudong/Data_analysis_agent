suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
})

#' Performs K-means clustering on numeric and categorical columns of a dataset.
#' Categorical variables are automatically one-hot encoded.
#'
#' @param path Path to the input CSV file.
#' @param n_clusters The number of clusters (k) to form. Defaults to 3.
#' @param variables Optional vector of column names to use for clustering. If NULL, all numeric columns (excluding 'id') are used.
#' @param out_path Path to save the output CSV file with an added 'cluster' column.
#' @return A list containing the path to the output CSV file.
tool_clustering <- function(path, n_clusters = 3, variables = NULL, out_path = "kmeans_with_labels.csv") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Determine clustering variables
  clustering_vars <- if (!is.null(variables) && length(variables) > 0) {
    variables[variables %in% names(df)]
  } else {
    # Default: Select all numeric columns but exclude any column named 'id'
    names(dplyr::select(df, where(is.numeric), -any_of("id")))
  }
  stopifnot(length(clustering_vars) > 0)

  # Clean data: remove rows with NAs in the selected variables
  df_clean <- tidyr::drop_na(df, all_of(clustering_vars))

  # Stop if no data is left for clustering
  if (nrow(df_clean) < n_clusters) {
    stop("Not enough data left for clustering after removing rows with missing values.")
  }

  # Separate variables by type for processing
  vars_data <- dplyr::select(df_clean, all_of(clustering_vars))
  numeric_vars <- names(dplyr::select(vars_data, where(is.numeric)))
  categorical_vars <- names(dplyr::select(vars_data, where(is.character), where(is.factor)))

  # Prepare the final data matrix for clustering
  data_for_clustering <- data.frame(row.names = rownames(vars_data))

  # Add numeric variables if they exist
  if (length(numeric_vars) > 0) {
    data_for_clustering <- cbind(data_for_clustering, vars_data[numeric_vars])
  }

  # One-hot encode categorical variables if they exist
  if (length(categorical_vars) > 0) {
    formula <- as.formula(paste("~", paste(categorical_vars, collapse = " + ")))
    # model.matrix creates dummy variables. The '-1' removes the intercept.
    dummy_vars <- model.matrix(formula, data = vars_data)[, -1, drop = FALSE]
    data_for_clustering <- cbind(data_for_clustering, dummy_vars)
  }

  if (ncol(data_for_clustering) == 0) {
    stop("No valid variables available for clustering after processing.")
  }

  # Scale the final prepared data (all numeric now)
  X_scaled <- scale(data_for_clustering)

  # Perform k-means
  set.seed(42)
  km <- stats::kmeans(X_scaled, centers = n_clusters, nstart = 20)

  # Add cluster labels to the original cleaned dataframe (not the one-hot encoded one)
  df_clean$cluster <- km$cluster

  # Write the result to the output file
  readr::write_csv(df_clean, out_path)

  # Return only the path to the output file for tool chaining
  list(output_file = normalizePath(out_path))
}