suppressPackageStartupMessages({library(readr); library(dplyr)})

#' Performs K-means clustering on numeric columns of a dataset.
#'
#' @param path Path to the input CSV file.
#' @param n_clusters The number of clusters (k) to form. Defaults to 3.
#' @param variables Optional vector of column names to use for clustering. If NULL, all numeric columns are used.
#' @param out_path Path to save the output CSV file with an added '.cluster' column.
#' @return A list containing the cluster centers, total within-cluster sum of squares, and the path to the output CSV.
tool_clustering <- function(path, n_clusters = 3, variables = NULL, out_path = "kmeans_with_labels.csv") {
  df <- readr::read_csv(path, show_col_types = FALSE)
  X <- if (!is.null(variables) && length(variables)>0)
    dplyr::select(df, dplyr::all_of(variables))
    else dplyr::select(df, where(is.numeric))
  stopifnot(ncol(X) > 0)
  set.seed(42)
  km <- stats::kmeans(X, centers = n_clusters, nstart = 10)
  df$.cluster <- km$cluster
  readr::write_csv(df, out_path)
  list(centers = km$centers, tot_withinss = km$tot.withinss, out_csv = normalizePath(out_path))
}
