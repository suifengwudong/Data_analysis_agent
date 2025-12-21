options(encoding = "UTF-8")
# sink(file = stderr(), type = "output")  # 把 stdout 全部重定向到 stderr

suppressPackageStartupMessages({
  library(mcptools)   # R 侧 MCP server
  library(ellmer)     # 定义工具schema
  library(readr); library(dplyr); library(ggplot2); library(broom); library(jsonlite)
})

# 加载工具实现（在 mcp_server/r_tools/ 下）
tool_dir <- "mcp_server/r_tools"
source(file.path(tool_dir, "eda_tools.R"))
source(file.path(tool_dir, "modeling_tools.R"))
source(file.path(tool_dir, "viz_tools.R"))
source(file.path(tool_dir, "clustering_tools.R"))
source(file.path(tool_dir, "stats_tools.R"))
source(file.path(tool_dir, "cleaning_tools.R"))

# 把 R 函数包装为 ellmer::tool （参数类型明确，方便 LLM 遵循）
r_eda <- ellmer::tool(
  tool_eda, name = "r_eda",
  description = "Exploratory data analysis (shape, NA, numeric summary, optional selected variables).",
  arguments = list(
    path = ellmer::type_string("Path to CSV"),
    variables = ellmer::type_array(ellmer::type_string(), "Optional column names", required = FALSE)
  )
)

r_clean_data <- ellmer::tool(
  tool_clean_data, name = "r_clean_data",
  description = "Cleans a CSV file by removing rows with NAs or zeros in specified columns, and filtering by a numeric range.",
  arguments = list(
    path = ellmer::type_string("Path to the input CSV file."),
    output_path = ellmer::type_string("Path to save the cleaned CSV file."),
    na_cols = ellmer::type_array(ellmer::type_string(), "Optional: Columns where rows with NA should be removed.", required = FALSE),
    zero_cols = ellmer::type_array(ellmer::type_string(), "Optional: Columns where rows with a value of 0 should be removed.", required = FALSE),
    filter_col = ellmer::type_string("Optional: Column name for numeric range filtering.", required = FALSE),
    min_val = ellmer::type_number("Optional: Minimum value for the range filter.", required = FALSE),
    max_val = ellmer::type_number("Optional: Maximum value for the range filter.", required = FALSE)
  )
)

r_linear_model <- ellmer::tool(
  tool_linear_model, name = "r_linear_model",
  description = "Fit linear model with diagnostics PNG.",
  arguments = list(
    path   = ellmer::type_string("CSV path"),
    formula_str = ellmer::type_string('R formula, e.g., "mpg ~ hp + wt"'),
    out_dir     = ellmer::type_string("Output dir", required = FALSE)
  )
)

r_visualize <- ellmer::tool(
  tool_visualize, name = "r_visualize",
  description = "Produce scatter/histogram/boxplot and save PNG. Can filter data and apply axis transformations.",
  arguments = list(
    path   = ellmer::type_string("CSV path"),
    plot_type   = ellmer::type_string("scatter|histogram|boxplot"),
    x_var       = ellmer::type_string("x var"),
    y_var       = ellmer::type_string("y var (for scatter)", required = FALSE),
    filter_expr = ellmer::type_string("A string of R expression to filter the data, e.g., 'col_a > 10 & col_b == \"some_value\"'", required = FALSE),
    x_trans     = ellmer::type_string("Transformation for x-axis (e.g., 'log10', 'sqrt')", required = FALSE),
    y_trans     = ellmer::type_string("Transformation for y-axis (e.g., 'log10', 'sqrt')", required = FALSE),
    output_path = ellmer::type_string("PNG path", required = FALSE)
  )
)

r_clustering <- ellmer::tool(
  tool_clustering, name = "r_clustering",
  description = "K-means on selected numeric columns; write labeled CSV.",
  arguments = list(
    path   = ellmer::type_string("CSV path"),
    n_clusters  = ellmer::type_integer("k (default 3)", required = FALSE),
    variables   = ellmer::type_array(ellmer::type_string(), "Optional columns", required = FALSE),
    out_path    = ellmer::type_string("Output CSV", required = FALSE)
  )
)

r_hypothesis_test <- ellmer::tool(
  tool_hypothesis_test, name = "r_hypothesis_test",
  description = "t-test or correlation between two numeric columns.",
  arguments = list(
    path = ellmer::type_string("CSV path"),
    test_type = ellmer::type_string("t_test|correlation"),
    var1      = ellmer::type_string("first variable"),
    var2      = ellmer::type_string("second variable", required = FALSE)
  )
)

mcptools::mcp_server(tools = list(
  r_eda, r_linear_model, r_visualize, r_clustering, r_hypothesis_test, r_clean_data
))
# install.packages(c('mcptools','ellmer','readr','dplyr','ggplot2','broom','jsonlite'))