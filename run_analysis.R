
options(encoding = "UTF-8")

# --- 1. Load Libraries & Tools ---
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(jsonlite)
  library(ggplot2)
  library(broom)
})

# Source tools
tool_dir <- "mcp_server/r_tools"
t_files <- list.files(tool_dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
invisible(lapply(t_files, source))

# --- 2. Define Data Path ---
data_path <- "temp_files/r_analysis_gradio_strorys_/Meteorite_Landings.csv"

if (!file.exists(data_path)) {
  stop("Data file not found at: ", data_path)
}

cat("========================================================\n")
cat("      STARTING SEQUENTIAL ANALYSIS: Meteorite Landings  \n")
cat("========================================================\n\n")

# --- 3. Step 1: Exploratory Data Analysis (EDA) ---
cat(">> Step 1: Basic EDA\n")
eda_res <- tool_eda(data_path)
print(eda_res$shape)
print(eda_res$na_count)
cat("\n")

# --- 4. Step 2: Normality Test (Original Variable) ---
cat(">> Step 2: Normality Test on 'mass (g)'\n")
# Shapiro-Wilk (might fail if N > 5000, but tool_normality_test uses stats::shapiro.test which has a limit)
# KS Test is safer for large N.
cat("   [Test 1] KS Test on Raw Mass:\n")
tryCatch({
    ks_res <- tool_ks_test(data_path, var = "mass (g)")
    print(ks_res)
}, error = function(e) { cat("   Error in KS Test: ", e$message, "\n") })

cat("   [Test 2] Shapiro-Wilk on Raw Mass (Sampled if necessary by internal function? No, tool uses raw):\n")
tryCatch({
    # We filter for mass > 0 to avoid -Inf in log later, and typically mass is positive.
    # Also Shapiro limit of 5000.
    # Let's see if the tool handles sampling or if we should filter.
    # The tool_normality_test does NOT sample. It might error on N > 5000.
    # We will try it.
    shapiro_res <- tool_normality_test(data_path, var = "mass (g)")
    print(shapiro_res)
}, error = function(e) { cat("   Error in Shapiro Test (Likely N > 5000): ", e$message, "\n") })
cat("\n")

# --- 5. Step 3: Transformation (Log10) ---
cat(">> Step 3: Data Transformation (Log10 of Mass)\n")
# Create a transformed file
clean_path <- "temp_files/r_analysis_gradio_strorys_/Meteorite_Landings_Transformed.csv"
# We first need to handle zeros? tool_transform_variable has add_constant.
tryCatch({
    transform_res <- tool_transform_variable(
        path = data_path,
        output_path = clean_path,
        vars = c("mass (g)"),
        method = "log10",
        add_constant = 1 # Log(Mass + 1)
    )
    cat("   Transformation successful. Saved to:", clean_path, "\n")
}, error = function(e) { cat("   Transformation Failed: ", e$message, "\n") })
cat("\n")

# --- 6. Step 4: Normality Test (Transformed Variable) ---
cat(">> Step 4: Normality Test on 'log10_mass (g)'\n")
# Note: tool_transform_variable usually prefixes columns (e.g. log10_mass (g)) or replaces them?
# Let's check transformation_tools.R logic. It usually creates "method_varname".
# Let's assume "log10_mass (g)".
tryCatch({
    # Need to read the file to know the new column name
    df_trans <- read_csv(clean_path, show_col_types = FALSE)
    new_cols <- names(df_trans)
    target_col <- grep("log10", new_cols, value = TRUE)[1]
    
    cat("   Testing column:", target_col, "\n")
    
    ks_log_res <- tool_ks_test(clean_path, var = target_col)
    print(ks_log_res)
}, error = function(e) { cat("   Error in Testing Transformed data: ", e$message, "\n") })
cat("\n")

# --- 7. Step 5: Comparative Testing (Fall Status) ---
cat(">> Step 5: Comparative Testing (Mass vs Fall Status)\n")
# Using Wilcoxon Rank Sum Test (Non-parametric, robust to outliers/non-normality)
cat("   [Test] Wilcoxon Rank Sum Test (Mass ~ Fall)\n")
tryCatch({
    wilcox_res <- tool_wilcox_test(data_path, formula_str = "`mass (g)` ~ fall")
    print(wilcox_res)
}, error = function(e) { cat("   Error in Wilcoxon Test: ", e$message, "\n") })
cat("\n")

cat("   [Test] T-Test (Mass ~ Fall) -- for comparison\n")
tryCatch({
    t_res <- tool_t_test(data_path, formula_str = "`mass (g)` ~ fall")
    print(t_res)
}, error = function(e) { cat("   Error in T-Test: ", e$message, "\n") })
cat("\n")

cat("========================================================\n")
cat("      ANALYSIS COMPLETE\n")
cat("========================================================\n")
