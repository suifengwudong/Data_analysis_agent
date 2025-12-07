suppressPackageStartupMessages({library(readr); library(dplyr)})

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
