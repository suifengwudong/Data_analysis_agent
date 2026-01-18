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
    filter_expr = ellmer::type_string("Optional R expression to filter data before testing.", required = FALSE),
    transform = ellmer::type_string("Optional transformation for the variable (e.g., 'log10', 'sqrt').", required = FALSE)
  )
)

r_wilcox_test <- ellmer::tool(
  tool_wilcox_test, name = "r_wilcox_test",
  description = "Performs a Wilcoxon rank-sum test (or Mann-Whitney U test) as a non-parametric alternative to the t-test.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    formula_str = ellmer::type_string("An R formula, e.g., 'numeric_var ~ grouping_var'."),
    paired = ellmer::type_boolean("Whether to perform a paired test. Default is FALSE.", required = FALSE)
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

r_hypothesis_test <- ellmer::tool(
  tool_hypothesis_test, name = "r_hypothesis_test",
  description = "Performs a hypothesis test (t-test, Mann-Whitney U, or correlation) between two numeric columns.",
  arguments = list(
    path = ellmer::type_string("CSV path"),
    test_type = ellmer::type_string("t_test|mann_whitney_u|correlation"),
    var1      = ellmer::type_string("First variable"),
    var2      = ellmer::type_string("Second variable")
  )
)

r_normality_test <- ellmer::tool(
  tool_normality_test, name = "r_normality_test",
  description = "Performs a Shapiro-Wilk normality test on a single variable after optional filtering and transformation.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    var = ellmer::type_string("The name of the variable to test."),
    filter_expr = ellmer::type_string("Optional: An R expression to filter data before testing.", required = FALSE),
    transform = ellmer::type_string("Optional: Transformation to apply before testing (e.g., 'log10', 'sqrt').", required = FALSE)
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
  r_hypothesis_test,
  r_clean_data,
  r_plot_map,
  r_normality_test,
  r_anova
))