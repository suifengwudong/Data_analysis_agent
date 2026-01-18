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
#' @param feature_weights Optional named list of weights for variables.
#'        E.g., list(reclat = 0.5, recclass = 2).
#'        Weights are applied after scaling. For categorical variables, the weight is applied to all corresponding one-hot columns.
#' @return A list containing the path to the output CSV file.
tool_clustering <- function(path, n_clusters = 3, variables = NULL, out_path = "kmeans_with_labels.csv", feature_weights = NULL) {
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

  # Apply feature weights if provided
  if (!is.null(feature_weights)) {
    # If feature_weights is a JSON string (passed from LLM as string), parse it
    if (is.character(feature_weights) && length(feature_weights) == 1) {
       tryCatch({
         feature_weights <- jsonlite::fromJSON(feature_weights)
       }, error = function(e) {
         stop("Failed to parse feature_weights JSON string: ", e$message)
       })
    }
  
    if (length(feature_weights) > 0) {
      col_names <- colnames(X_scaled)
      for (var_name in names(feature_weights)) {
        weight <- feature_weights[[var_name]]
        # Case 1: Exact match (numeric variable)
        if (var_name %in% col_names) {
          X_scaled[, var_name] <- X_scaled[, var_name] * weight
        } else {
          # Case 2: Categorical variable prefix match
          # Find columns that look like "var_nameValue" (created by model.matrix)
          # Using exact start matching
          matches <- grep(paste0("^", var_name), col_names)
          if (length(matches) > 0) {
            X_scaled[, matches] <- X_scaled[, matches] * weight
          }
        }
      }
    }
  }

  # Perform k-means
  set.seed(42)
  km <- stats::kmeans(X_scaled, centers = n_clusters, nstart = 20)

  # Add cluster labels to the original cleaned dataframe (not the one-hot encoded one)
  df_clean$cluster <- km$cluster

  # Create a summary of the clusters (sizes and means of numeric variables)
  summary_stats <- df_clean %>%
    dplyr::group_by(cluster) %>%
    dplyr::summarise(count = n(), dplyr::across(where(is.numeric), mean, .names = "mean_{.col}"))

  # Format summary as text
  summary_text <- paste(capture.output(print(summary_stats, width = 100)), collapse = "\n")

  # Save summary to file
  summary_path <- gsub("\\.csv$", "_summary.txt", out_path)
  writeLines(summary_text, summary_path)

  # Write the result to the output file
  readr::write_csv(df_clean, out_path)

  # Return only the path to the output file for tool chaining
  list(
      output_file = normalizePath(out_path),
      cluster_summary = summary_text
  )
}