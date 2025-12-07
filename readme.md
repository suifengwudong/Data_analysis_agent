# R 数据分析智能体框架

这是本课程的项目框架。它是一个 Python AI 智能体，通过调用自定义的 R 工具完成数据分析。

## 项目简介

这个项目是为了学习如何与 AI 协同工作。AI 智能体 ( `gpt-4o` ) 负责理解需求、制定计划和调用工具，你负责提供核心的统计分析能力。你的工作是将分析任务工具化，即编写独立的、可被 AI 调用的 R 函数。

---

## 任务

核心任务不是编写 Python 代码，所有的工作都在 `mcp_server/` 文件夹内完成。

**工作是：**

1.  **编写/修改 R 函数：** 在 `mcp_server/r_tools/` 目录中，修改现有的 `.R` 文件（如 `eda_tools.R`, `modeling_tools.R`）或创建新的 `.R` 文件，以实现项目所需的特定分析。
2.  **“注册” R 工具：** 在 `mcp_server/r_mcp_server.R` 文件中，需要：
    * `source()` 新创建的 `.R` 文件。
    * 使用 `ellmer::tool()` 将 R 函数包装成 AI 可以理解的工具（定义函数名、描述和参数）。
    * 将定义好的工具添加到 `mcptools::mcp_server()` 的 `tools` 列表中。

AI 智能体将**自动发现** `r_mcp_server.R` 中注册的所有工具，并在需要时调用它们。

---

## 快速开始

### 1. 环境准备

**Python 环境:**
本项目需要 Python 3.9+。

```bash
# 建议创建虚拟环境
python -m venv venv
source venv/bin/activate  # (macOS/Linux)
# .\venv\Scripts\activate  # (Windows)

# 安装 Python 依赖
pip install -r requirements.txt
```

**R 环境:**

1. 确保已安装 R，并且 `Rscript` 命令已添加到系统 PATH 中。

2. 安装 R 依赖包。打开 R 控制台并运行：

```R
install.packages(c('mcptools', 'ellmer', 'readr', 'dplyr', 'ggplot2', 'broom', 'jsonlite'))
```

### 2. 配置 (Configuration)

1. 在项目根目录创建一个 `.env` 文件。
2. 在 `.env` 文件中填入 `OPENAI_API_KEY`（使用课程开放的API_KEY即可）。

```python
# .env
OPENAI_API_KEY=sk-YourKeyHere

# (可选) 如果 Rscript 不在默认 PATH 中，请取消注释并指定 Rscript.exe/Rscript 的完整路径
# RSCRIPT_BIN=C:\Program Files\R\R-4.x.x\bin/Rscript.exe
```

### 3. 运行 (Run)

本项目支持 Gradio (Web 界面) 和 CLI (命令行) 两种模式。

**方式一: 启动 Gradio Web 界面 (推荐)** 这是默认模式。

```bash
python main.py
```

启动后，系统会自动打开浏览器访问 Web UI，可以在界面上上传数据、提出分析需求。

**方式二: 启动 CLI 命令行**

```bash
python main.py --mode cli
```

可以在命令行中直接与 Agent 交互。

------

## 如何添加一个新的 R Tool (示例)

假设需要添加一个**逻辑回归 (Logistic Regression)** 工具。

### Step 1: 编写 R 函数

在 `mcp_server/r_tools/` 目录下创建一个新文件，例如 `logistic_tool.R`。

```R
# mcp_server/r_tools/logistic_tool.R

suppressPackageStartupMessages({library(readr); library(broom)})

tool_logistic_model <- function(path, formula_str, out_dir=".") {
  # 1. 读取数据
  df <- readr::read_csv(path, show_col_types = FALSE)
  
  # 2. 拟合模型
  # 确保 family = "binomial"
  fit <- stats::glm(stats::as.formula(formula_str), data = df, family = "binomial")
  
  # 3. 创建输出
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  
  # 4. (可选) 保存诊断图
  png(file.path(out_dir, "logistic_diag.png"), width = 800, height = 600)
  par(mfrow=c(2,2)); plot(fit); dev.off()
  
  # 5. 返回结果 (Tidy 格式)
  list(
    glance = broom::glance(fit),
    tidy   = broom::tidy(fit, exponentiate = TRUE), # exponentiate=TRUE 获取 OR (优势比)
    diag_plot = normalizePath(file.path(out_dir, "logistic_diag.png"))
  )
}
```

### Step 2: 在 `r_mcp_server.R` 中注册

打开 `mcp_server/r_mcp_server.R` 文件。

```R
# r_mcp_server.R

# ... (其他 library)

# 1. Source 新的 R 文件 (在文件顶部)
tool_dir <- "mcp_server/r_tools"
source(file.path(tool_dir, "eda_tools.R"))
source(file.path(tool_dir, "modeling_tools.R"))
# ... (其他 source)
source(file.path(tool_dir, "logistic_tool.R")) # <-- 在这里添加

# ... (其他工具的 ellmer::tool 定义) ...

# 2. 包装新的工具 (ellmer::tool)
r_logistic_model <- ellmer::tool(
  tool_logistic_model, name = "r_logistic_model",
  description = "拟合逻辑回归模型 (Fit logistic regression model) 并返回模型摘要和诊断图。",
  arguments = list(
    path   = ellmer::type_string("CSV 文件的路径"),
    formula_str = ellmer::type_string('R 语言公式, e.g., "target ~ var1 + var2"'),
    out_dir     = ellmer::type_string("输出目录", required = FALSE)
  )
)

# ...

# 3. 将工具添加到 mcp_server 列表
mcptools::mcp_server(tools = list(
  r_eda, 
  r_linear_model, 
  r_visualize, 
  r_clustering, 
  r_hypothesis_test,
  r_logistic_model  # <-- 在这里添加
))
```

### Step 3: 运行和测试

重启 `python main.py`。现在 AI 智能体已经可以访问 `r_logistic_model` 工具了。

可以向它提问：“请帮我使用 xxx.csv 数据集，拟合一个逻辑回归模型，公式为 `y ~ x1 + x2`。”

------

## 项目结构

```
.
├── agent/                  # AI 智能体 (无需修改)
│   └── data_analysis_agent.py
├── mcp_client/             # Python-R 客户端 (无需修改)
│   └── client.py
├── mcp_server/             # 主要工作区
│   ├── r_tools/            # (核心) 在此编写/修改 R 工具
│   │   ├── clustering_tools.R
│   │   ├── eda_tools.R
│   │   ├── modeling_tools.R
│   │   ├── stats_tools.R
│   │   └── viz_tools.R
│   └── r_mcp_server.R      # (核心) 在此注册 R 工具
├── tools/                  # Python 端工具 (无需修改)
│   ├── talk_to_user_gradio_tool.py
│   └── talk_to_user_tool.py
├── ui/                     # Gradio Web 界面 (无需修改)
│   └── gradio_ui.py
├── .env                    # API 密钥
├── main.py                 # 项目主入口
└── requirements.txt        # Python 依赖
```