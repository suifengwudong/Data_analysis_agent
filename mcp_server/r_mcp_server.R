options(encoding = "UTF-8")

suppressPackageStartupMessages({
  library(mcptools)   # R 侧 MCP server
  library(ellmer)     # 定义工具schema
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(broom)
  library(jsonlite)
  library(moments)
})

# Recursively find and source all R tool files
tool_dir <- "mcp_server/r_tools"
tool_files <- list.files(path = tool_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
invisible(lapply(tool_files, source))

# 把 R 函数包装为 ellmer::tool （参数类型明确，方便 LLM 遵循）
r_eda <- ellmer::tool(
  tool_eda, name = "r_eda",
  description = "Exploratory data analysis (shape, NA, numeric summary, optional selected variables).",
  arguments = list(
    path = ellmer::type_string("Path to CSV"),
    variables = ellmer::type_array(ellmer::type_string(), "Optional column names", required = FALSE)
  )
)

r_plot_map <- ellmer::tool(
  tool_plot_map, name = "r_plot_map",
  description = "Plots geographic points from a CSV file onto a world map.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    lon_var = ellmer::type_string("The name of the longitude column."),
    lat_var = ellmer::type_string("The name of the latitude column."),
    filter_expr = ellmer::type_string("Optional: An R expression to filter data before plotting.", required = FALSE),
    color_var = ellmer::type_string("Optional: A column name to use for coloring the points.", required = FALSE),
    color_scale = ellmer::type_string("Optional: Color scale for numeric color_var ('gradient', 'viridis', 'discrete').", required = FALSE),
    output_path = ellmer::type_string("Optional: Path to save the output map PNG file.", required = FALSE)
  )
)

r_clean_data <- ellmer::tool(
  tool_clean_data, name = "r_clean_data",
  description = "Cleans a CSV file by standardizing column names, removing rows with NAs or zeros, and filtering by a numeric range.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    output_path = ellmer::type_string("Path to save the cleaned CSV file."),
    clean_colnames = ellmer::type_boolean("If TRUE (default), standardizes column names to be R-friendly.", required = FALSE),
    na_cols = ellmer::type_array(ellmer::type_string(), "Optional: Columns where rows with NA should be removed.", required = FALSE),
    zero_cols = ellmer::type_array(ellmer::type_string(), "Optional: Columns where rows with a value of 0 should be removed.", required = FALSE),
    filter_col = ellmer::type_string("Optional: Column name for numeric range filtering.", required = FALSE),
    min_val = ellmer::type_number("Optional: Minimum value for the range filter.", required = FALSE),
    max_val = ellmer::type_number("Optional: Maximum value for the range filter.", required = FALSE)
  )
)

r_filter_data <- ellmer::tool(
  tool_filter_data, name = "r_filter_data",
  description = "Filters data by retaining rows where a column matches a specific value (e.g. category filtering).",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    output_path = ellmer::type_string("Path to save the filtered CSV file."),
    filter_col = ellmer::type_string("The column name to filter by."),
    filter_value = ellmer::type_string("The value to keep."),
    keep = ellmer::type_boolean("If TRUE (default), keep rows that match. If FALSE, discard them.", required = FALSE)
  )
)

r_transform_variable <- ellmer::tool(
  tool_transform_variable, name = "r_transform_variable",
  description = "Applies a mathematical transformation (e.g., log10, log, sqrt) to specified columns in a dataset.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    output_path = ellmer::type_string("Path to save the transformed CSV file."),
    vars = ellmer::type_array(ellmer::type_string(), "A list of column names to transform."),
    method = ellmer::type_string("The transformation method: 'log10', 'log', or 'sqrt'.", required = FALSE),
    add_constant = ellmer::type_number("A small constant to add before transforming to avoid issues like log(0).", required = FALSE)
  )
)

r_moving_average <- ellmer::tool(
  tool_moving_average, name = "r_moving_average",
  description = "Calculates a centered moving average (rolling mean) for a time series variable.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    output_path = ellmer::type_string("Path to save the transformed CSV file."),
    time_col = ellmer::type_string("Column name for time/ordering."),
    value_col = ellmer::type_string("Column name for values to smooth."),
    window_size = ellmer::type_integer("Size of the moving window. Default 5.", required = FALSE)
  )
)

r_filter_by_frequency <- ellmer::tool(
  tool_filter_by_frequency, name = "r_filter_by_frequency",
  description = "Filters data by keeping only groups that appear frequently (e.g. Top N categories).",
  arguments = list(
    path = ellmer::type_string("Path to CSV."),
    output_path = ellmer::type_string("Path to save filtered CSV."),
    group_col = ellmer::type_string("Categorical column to filter by."),
    min_count = ellmer::type_integer("Keep groups with at least this many rows.", required = FALSE),
    top_n = ellmer::type_integer("Keep top N largest groups.", required = FALSE)
  )
)

r_glm <- ellmer::tool(
  tool_glm, name = "r_glm",
  description = "Fits a Generalized Linear Model (e.g., linear or logistic regression), saves the model summary to a text file, and provides diagnostic plots.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string('R formula, e.g., "y ~ x1 + x2".'),
    family = ellmer::type_string('Model family: "gaussian" (linear), "binomial" (logistic), etc.', required = FALSE),
    out_dir = ellmer::type_string("Directory to save summary and plots.", required = FALSE)
  )
)

r_regularized_regression <- ellmer::tool(
  tool_regularized_regression, name = "r_regularized_regression",
  description = "Performs regularized regression (Lasso, Ridge, Elastic Net), saves coefficients to a CSV, and returns paths to the plot and CSV.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string('R formula, e.g., "y ~ x1 + x2".'),
    model_type = ellmer::type_string('Type of regularization: "lasso", "ridge", or "elastic_net".', required = FALSE),
    alpha = ellmer::type_number("Elastic Net mixing parameter (0=ridge, 1=lasso). Used only if model_type is elastic_net.", required = FALSE),
    family = ellmer::type_string('Model family: "gaussian" (linear) or "binomial" (logistic).', required = FALSE),
    out_path = ellmer::type_string("Path to save the cross-validation plot and coefficients CSV.", required = FALSE)
  )
)

r_visualize <- ellmer::tool(
  tool_visualize, name = "r_visualize",
  description = "Produce scatter, histogram, boxplot, or kde plot. Can filter data and apply axis transformations.",
  arguments = list(
    path        = ellmer::type_string("CSV path"),
    plot_type   = ellmer::type_string("scatter|histogram|boxplot|kde"),
    x_var       = ellmer::type_string("X-axis variable. For boxplot, can be a grouping variable."),
    y_var       = ellmer::type_string("Y-axis variable (for scatter and grouped boxplot).", required = FALSE),
    color_var   = ellmer::type_string("Optional: A column name to use for coloring the plot elements.", required = FALSE),
    color_scale = ellmer::type_string("Optional: Color scale for numeric color_var ('gradient', 'viridis', 'discrete').", required = FALSE),
    filter_expr = ellmer::type_string("A string of R expression to filter the data, e.g., 'col_a > 10'", required = FALSE),
    x_trans     = ellmer::type_string("Transformation for x-axis (e.g., 'log10', 'sqrt').", required = FALSE),
    y_trans     = ellmer::type_string("Transformation for y-axis (e.g., 'log10', 'sqrt').", required = FALSE),
    output_path = ellmer::type_string("PNG path", required = FALSE)
  )
)

r_ks_test <- ellmer::tool(
  tool_ks_test, name = "r_ks_test",
  description = "Performs a Kolmogorov-Smirnov (K-S) test for normality on a single variable.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    var = ellmer::type_string("The name of the variable to test."),
    filter_expr = ellmer::type_string("Optional R expression to filter data before testing.", required = FALSE)
  )
)

r_wilcox_test <- ellmer::tool(
  tool_wilcox_test, name = "r_wilcox_test",
  description = "Performs a Wilcoxon rank-sum test (or Mann-Whitney U test) as a non-parametric alternative to the t-test.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string("An R formula, e.g., 'numeric_var ~ grouping_var'."),
    paired = ellmer::type_boolean("Whether to perform a paired test. Default is FALSE.", required = FALSE),
    alternative = ellmer::type_string("Alternative hypothesis: 'two.sided', 'less', 'greater'. Default 'two.sided'.", required = FALSE)
  )
)

r_pairwise_test <- ellmer::tool(
  tool_pairwise_test, name = "r_pairwise_test",
  description = "Performs pairwise comparison tests (e.g., Wilcoxon) between groups and visualizes p-values as a heatmap.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string("An R formula, e.g., 'numeric_var ~ grouping_var'."),
    test_method = ellmer::type_string("The pairwise test method: 'wilcox.test' or 't.test'.", required = FALSE),
    p_adjust_method = ellmer::type_string("Method for p-value adjustment (e.g., 'holm', 'bonferroni').", required = FALSE),
    output_path = ellmer::type_string("Path to save the output heatmap PNG file.", required = FALSE)
  )
)

r_clustering <- ellmer::tool(
  tool_clustering, name = "r_clustering",
  description = "Performs K-means clustering on specified numeric variables and returns a CSV with cluster labels.",
  arguments = list(
    path   = ellmer::type_string("CSV path"),
    n_clusters  = ellmer::type_integer("k (default 3)", required = FALSE),
    variables   = ellmer::type_array(ellmer::type_string(), "Optional columns for clustering. If NULL, all numeric columns are used.", required = FALSE),
    out_path    = ellmer::type_string("Output CSV path", required = FALSE)
  )
)

r_t_test <- ellmer::tool(
  tool_t_test, name = "r_t_test",
  description = "Performs a Student's t-test or Welch's t-test between two groups.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string("Formula, e.g. 'numeric_col ~ group_col'."),
    paired = ellmer::type_boolean("Perform paired t-test? Default FALSE.", required = FALSE),
    var_equal = ellmer::type_boolean("Assume equal variances? TRUE=Student, FALSE=Welch. Default FALSE.", required = FALSE),
    alternative = ellmer::type_string("Alternative hypothesis: 'two.sided', 'less', 'greater'. Default 'two.sided'.", required = FALSE)
  )
)

r_correlation <- ellmer::tool(
  tool_correlation, name = "r_correlation",
  description = "Calculates correlation (Pearson, Kendall, Spearman) between two numeric variables.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    var1 = ellmer::type_string("First numeric variable."),
    var2 = ellmer::type_string("Second numeric variable."),
    method = ellmer::type_string("Correlation method: 'pearson', 'kendall', 'spearman'. Default 'pearson'.", required = FALSE)
  )
)

r_normality_test <- ellmer::tool(
  tool_normality_test, name = "r_normality_test",
  description = "Performs a Shapiro-Wilk normality test on a single variable.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    var = ellmer::type_string("The name of the variable to test."),
    filter_expr = ellmer::type_string("Optional: An R expression to filter data before testing.", required = FALSE)
  )
)

r_anova <- ellmer::tool(
  tool_anova, name = "r_anova",
  description = "Performs ANOVA (single or multi-factor) and saves the summary and diagnostic plots.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string('R formula for ANOVA, e.g., "dependent_var ~ factor1 * factor2".'),
    out_dir = ellmer::type_string("Directory to save the summary and plots.", required = FALSE)
  )
)

mcptools::mcp_server(tools = list(
  r_eda,
  r_glm,
  r_regularized_regression,
  r_visualize,
  r_clustering,
  r_clean_data,
  r_plot_map,
  r_normality_test,
  r_anova,
  r_t_test,
  r_correlation,
  r_ks_test,
  r_wilcox_test,
  r_pairwise_test,
  r_transform_variable,
  r_moving_average,
  r_filter_by_frequency,
  r_filter_data
))