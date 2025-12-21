suppressPackageStartupMessages({
  library(readr)
  library(ggplot2)
  library(dplyr)
  library(sf)
  library(maps)
})

#' Plots geographic points on a world map.
#'
#' @param path Path to the input CSV file.
#' @param lon_var The name of the longitude column.
#' @param lat_var The name of the latitude column.
#' @param filter_expr An optional R expression string to filter the data before plotting.
#' @param color_var An optional column name to use for coloring the points.
#' @param color_scale An optional string specifying the color scale to use for numeric `color_var`.
#'   Can be "gradient" (default), "viridis", or "discrete".
#' @param output_path The path to save the output map PNG file.
#' @return A list containing the path to the saved map plot.
tool_plot_map <- function(path,
                          lon_var,
                          lat_var,
                          filter_expr = NULL,
                          color_var = NULL,
                          color_scale = "gradient",
                          output_path = "map_plot.png") {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Apply filtering if filter_expr is provided
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    df <- dplyr::filter(df, !!rlang::parse_expr(filter_expr))
  }

  stopifnot(lon_var %in% names(df), lat_var %in% names(df))

  # Get world map data
  world_map <- ggplot2::map_data("world")

  # If the color variable is numeric but should be treated as discrete (like cluster IDs), convert it to a factor.
  # This is the most robust way to ensure ggplot uses a discrete color scale.
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    if (is.numeric(df[[color_var]]) && color_scale != "gradient" && color_scale != "viridis") {
      df[[color_var]] <- as.factor(df[[color_var]])
    }
  }

  # Create the plot
  p <- ggplot() +
    # Draw the world map background
    geom_polygon(data = world_map, aes(x = long, y = lat, group = group), fill = "gray80", color = "white")

  # Base aesthetic mapping
  point_aes <- aes(x = .data[[lon_var]], y = .data[[lat_var]])

  # Add color aesthetic if color_var is valid and exists in the dataframe
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    point_aes$colour <- rlang::sym(color_var)
  }

  # Add the points layer
  p <- p + geom_point(data = df, mapping = point_aes, alpha = 0.6)

  # Apply color scale if color_var is specified and valid
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    if (is.numeric(df[[color_var]]) && color_scale != "discrete") {
      if (color_scale == "viridis") {
        p <- p + scale_color_viridis_c()
      } else { # Default to gradient
        p <- p + scale_color_gradient(low = "blue", high = "red")
      }
    } else {
      # For character, factor, or when discrete is explicitly requested
      p <- p + scale_color_discrete()
    }
  }

  # Add theme and labels
  p <- p +
    # Use a minimal theme
    theme_minimal() +
    labs(
      title = "Geographic Distribution",
      x = "Longitude",
      y = "Latitude",
      color = if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) color_var else NULL
    ) +
    # Ensure correct coordinate system
    coord_map(projection = "mercator", xlim = c(-180, 180))

  # Save the plot
  ggsave(output_path, p, width = 12, height = 7, dpi = 150)

  list(output = normalizePath(output_path))
}
