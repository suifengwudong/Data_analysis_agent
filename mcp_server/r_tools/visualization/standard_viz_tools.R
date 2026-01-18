suppressPackageStartupMessages({
  library(readr)
  library(ggplot2)
  library(dplyr)
})

#' Generates a plot (scatter, histogram, boxplot, or kde) from a CSV file.
#'
#' @param path Path to the input CSV file.
#' @param plot_type The type of plot to generate: "scatter", "histogram", "boxplot", or "kde".
#' @param x_var The column name for the x-axis. For boxplot, this can be the grouping variable.
#' @param y_var The column name for the y-axis (required for scatter and grouped boxplots).
#' @param color_var An optional column name to use for coloring the plot elements.
#' @param color_scale An optional string for numeric `color_var`: "gradient", "viridis", or "discrete".
#' @param filter_expr An optional R expression string to filter the data before plotting.
#' @param x_trans An optional transformation for the x-axis (e.g., 'log10').
#' @param y_trans An optional transformation for the y-axis (e.g., 'log10').
#' @param output_path The path to save the output plot PNG file.
#' @return A list containing the path to the saved plot.
tool_visualize <- function(path,
                           plot_type,
                           x_var,
                           y_var = NULL,
                           color_var = NULL,
                           color_scale = "gradient",
                           filter_expr = NULL,
                           x_trans = NULL,
                           y_trans = NULL,
                           output_path = "plot.png") {
  df <- readr::read_csv(path, show_col_types = FALSE)

  # Apply filtering if filter_expr is provided
  if (!is.null(filter_expr) && nzchar(filter_expr)) {
    df <- dplyr::filter(df, !!rlang::parse_expr(filter_expr))
  }

  # If the color variable is numeric but should be treated as discrete (like cluster IDs), convert it to a factor.
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    if (is.numeric(df[[color_var]]) && color_scale == "discrete") {
      df[[color_var]] <- as.factor(df[[color_var]])
    }
  }

  # For grouped boxplots, ensure the grouping variable is treated as a factor.
  if (plot_type == "boxplot" && !is.null(y_var)) {
    df[[x_var]] <- as.factor(df[[x_var]])
  }

  if (!x_var %in% names(df)) {
    stop(paste0("x_var '", x_var, "' not found in data. Available: ", paste(names(df), collapse = ", ")))
  }

  # Base aesthetic mapping
  base_aes <- aes()
  color_aes_type <- "color" # default aesthetic is 'color'

  p <- switch(plot_type,
    "scatter"   = {
      if (is.null(y_var) || !y_var %in% names(df)) {
        stop(paste0("Scatter plot requires y_var. Provided: '", y_var, "'. Available: ", paste(names(df), collapse = ", ")))
      }
      base_aes <- aes(.data[[x_var]], .data[[y_var]])
      ggplot(df) + geom_point()
    },
    "histogram" = {
      base_aes <- aes(.data[[x_var]])
      color_aes_type <- "fill" # Use fill for histograms
      ggplot(df) + geom_histogram(bins = 30, position = "identity", alpha = 0.7)
    },
    "boxplot"   = {
      color_aes_type <- "fill" # Use fill for boxplots
      if (is.null(y_var)) { # Single boxplot
        base_aes <- aes(y = .data[[x_var]])
        ggplot(df) + geom_boxplot()
      } else { # Grouped boxplot
        if (!y_var %in% names(df)) {
          stop(paste0("Boxplot requires y_var to be present in data. Provided: '", y_var, "'. Available: ", paste(names(df), collapse = ", ")))
        }
        base_aes <- aes(x = .data[[x_var]], y = .data[[y_var]])
        ggplot(df) + geom_boxplot()
      }
    },
    "kde" = {
      base_aes <- aes(.data[[x_var]])
      ggplot(df) + geom_density(alpha = 0.5)
    },
    stop("unsupported plot_type. Must be one of 'scatter', 'histogram', 'boxplot', 'kde'")
  )

  # Add color aesthetic if color_var is valid
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    # For kde, we might want to color the line and fill the area
    if (plot_type == "kde") {
      base_aes <- aes(x = .data[[x_var]], color = .data[[color_var]], fill = .data[[color_var]])
    } else {
      base_aes[[color_aes_type]] <- rlang::sym(color_var)
    }
  }

  # Apply aesthetics to the plot
  p <- p + base_aes

  # Apply color scale if color_var is specified and valid
  if (!is.null(color_var) && nzchar(color_var) && color_var %in% names(df)) {
    scale_func <- if (color_aes_type == "fill") scale_fill_gradient else scale_color_gradient
    viridis_func <- if (color_aes_type == "fill") scale_fill_viridis_c else scale_color_viridis_c
    discrete_func <- if (color_aes_type == "fill") scale_fill_discrete else scale_color_discrete

    if (is.numeric(df[[color_var]]) && color_scale != "discrete") {
      if (color_scale == "viridis") {
        p <- p + viridis_func()
      } else { # Default to gradient
        p <- p + scale_func(low = "blue", high = "red")
      }
    } else {
      # For character, factor, or when discrete is explicitly requested
      p <- p + discrete_func()
    }
  }

  ggsave(output_path, p, width = 8, height = 6, dpi = 150)
  list(output = normalizePath(output_path))
}
