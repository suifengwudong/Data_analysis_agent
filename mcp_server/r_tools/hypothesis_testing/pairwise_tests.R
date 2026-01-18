suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
})

#' Performs pairwise comparison tests (e.g., Wilcoxon or t-test) between groups
#' and visualizes the results as a heatmap.
#'
#' @param path Path to the input CSV file.
#' @param formula_str An R formula string, e.g., "numeric_var ~ grouping_var".
#' @param test_method The pairwise test method to use. Supported: "wilcox.test", "t.test".
#' @param p_adjust_method The method for adjusting p-values for multiple comparisons.
#'   (e.g., "holm", "bonferroni", "none").
#' @param output_path Path to save the output heatmap PNG file.
#' @return A list containing the path to the heatmap plot and the tidy results of the pairwise tests.
tool_pairwise_test <- function(path,
                               formula_str,
                               test_method = "wilcox.test",
                               p_adjust_method = "holm",
                               output_path = "pairwise_heatmap.png") {

  stopifnot(file.exists(path))
  df <- readr::read_csv(path, show_col_types = FALSE)
  
  formula <- as.formula(formula_str)
  response_var <- all.vars(formula)[1]
  grouping_var <- all.vars(formula)[2]

  # Perform pairwise test
  # The standard R functions are pairwise.t.test and pairwise.wilcox.test
  # We need to dispatch based on test_method
  
  if (test_method == "wilcox.test") {
      pairwise_result <- stats::pairwise.wilcox.test(
        x = df[[response_var]],
        g = df[[grouping_var]],
        p.adjust.method = p_adjust_method,
        paired = FALSE
      )
  } else if (test_method == "t.test") {
      pairwise_result <- stats::pairwise.t.test(
        x = df[[response_var]],
        g = df[[grouping_var]],
        p.adjust.method = p_adjust_method,
        paired = FALSE
      )
  } else {
      stop("Unsupported test_method. Use 'wilcox.test' or 't.test'.")
  }
  
  # Tidy the p-value matrix for plotting
  p_matrix <- as.data.frame(pairwise_result$p.value)
  p_matrix$group1 <- rownames(p_matrix)
  
  tidy_p_values <- p_matrix %>%
    tidyr::pivot_longer(
      cols = -group1,
      names_to = "group2",
      values_to = "p.value"
    ) %>%
    filter(!is.na(p.value))

  # Create the heatmap
  heatmap_plot <- ggplot(tidy_p_values, aes(x = group1, y = group2, fill = p.value)) +
    geom_tile(color = "white") +
    scale_fill_gradient(low = "red", high = "white", name = "p-value") +
    geom_text(aes(label = ifelse(p.value < 0.05, "*", "")), color = "black", size = 6) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.title = element_blank()
    ) +
    labs(
      title = "Pairwise Comparison Heatmap",
      subtitle = paste("p-values adjusted with", p_adjust_method, "method"),
      caption = "* indicates p < 0.05"
    )
  
  # Save the plot
  ggsave(output_path, plot = heatmap_plot, width = 10, height = 8, dpi = 300)

  list(
    plot_path = normalizePath(output_path),
    test_results = broom::tidy(pairwise_result)
  )
}
