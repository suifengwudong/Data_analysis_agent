# R 数据分析智能体框架

一个基于 Python 和 R 的 AI 智能体框架，旨在通过调用自定义的 R 工具来完成复杂的数据分析任务。

## 目录

- [R 数据分析智能体框架](#r-数据分析智能体框架)
  - [目录](#目录)
  - [项目简介](#项目简介)
  - [项目实战：陨石数据分析](#项目实战陨石数据分析)
    - [1. 问题定义](#1-问题定义)
    - [2. 构建 Agent 的思路](#2-构建-agent-的思路)
  - [项目架构](#项目架构)
  - [快速开始](#快速开始)
    - [环境准备](#环境准备)
    - [配置](#配置)
    - [运行项目](#运行项目)
  - [开发工作流：添加新工具](#开发工作流添加新工具)
    - [第一步：编写 R 函数](#第一步编写-r-函数)
    - [第二步：注册 R 工具](#第二步注册-r-工具)
    - [第三步：测试新工具](#第三步测试新工具)
  - [项目结构](#项目结构)
  - [展望与未来改进](#展望与未来改进)
    - [1. 分析方法的深化](#1-分析方法的深化)
    - [2. 数据的多维融合](#2-数据的多维融合)
    - [3. 系统架构的升级](#3-系统架构的升级)

## 项目简介

本项目旨在探索 AI 智能体与传统统计分析工具（R语言）的协同工作模式。其核心思想是：

- **AI 智能体 (Agent)**：基于大语言模型（如 GPT-4o），负责理解用户的高级指令、制定分析计划、并调用合适的工具。
- **R 工具 (R Tools)**：开发者将核心的统计分析能力封装成独立的、可被调用的 R 函数。

在这种模式下，AI 负责“思考”，而 R 负责“计算”，让数据分析变得更加自动化和智能化。开发者的主要任务是提供高质量、模块化的 R 分析工具。

## 项目实战：陨石数据分析

本项目以 **NASA 陨石坠落 (Meteorite Landings)** 数据集为例，展示了如何构建一个能够执行专业级统计分析的智能体。

### 1. 问题定义

**背景与动机**
了解陨石的物理属性（大小、质量、成分）和时空分布规律对于行星科学和防御至关重要。本项目基于公开数据集，致力于解决以下科学问题：

-   **发现模式差异**: “目击坠落 (Fell)”与“被动发现 (Found)”的陨石在质量分布和地理落点上是否存在本质区别（如观测者偏差）？
-   **时空演变规律**: 随着近代科考活动（特别是南极科考）的增加，陨石发现的数量和平均质量呈现何种变化趋势？
-   **物理属性关联**: 陨石的化学分类 (`recclass`) 与其物理质量 (`mass`) 之间是否存在显著的相关性？
-   **地理聚类特征**: 能否通过地理坐标和物理属性将全球陨石划分为自然的群落？

**数据挑战**
-   **长尾分布**: 陨石质量呈现极度右偏特性，需进行对数变换 (`log10`)。
-   **数据质量**: 包含缺失坐标、异常年份、零质量等噪音。

### 2. 构建 Agent 的思路

为了实现严谨且自动化的分析，我们采用了 **"Python 编排 + R 计算"** 的混合架构：

-   **大脑层 (Python/LLM)**
    -   使用 GPT-4o 作为推理引擎。
    -   **结构化思维链**: 通过预设的 Prompt 模板，强制 Agent 遵循 `数据清洗 -> EDA -> 假设检验 -> 建模` 的标准统计流程。
    -   **自适应纠错**: 赋予 Agent 读取元数据 (`r_eda`) 的能力，当遇到“列名不匹配”等 R 错误时，Agent 能自主修正公式。

-   **执行层 (R MCP Server)**
    -   封装专业的 R 包 (`dplyr`, `ggplot2`, `stats`) 为标准化原子工具。
    -   **工具链设计**:
        -   **数据清洗**: `r_clean_data`, `r_transform_variable`
        -   **可视化**: `r_plot_map` (地图), `r_visualize` (KDE/箱线图)
        -   **统计检验**: `r_wilcox_test`, `r_ks_test`, `r_pairwise_test`
        -   **建模**: `r_clustering` (K-Means), `r_glm` (回归)

通过这种设计，智能体不仅能生成代码，还能像人类分析师一样，用 P 值和图表来支撑每一个业务结论。

## 项目架构

本框架由以下几个关键组件构成：

- **`agent/`**: AI 智能体的大脑，负责处理用户请求和决策。**（无需修改）**
- **`mcp_server/`**: **核心工作区**。它是一个 R 服务，用于定义和暴露 R 工具，使其能被 Python 调用。
- **`mcp_client/`**: Python 客户端，负责与 R 服务进行通信。**（无需修改）**
- **`ui/`**: 基于 Gradio 的 Web 用户界面，提供用户交互入口。**（无需修改）**
- **`tools/`**: Python 端的工具，主要用于智能体与用户进行交互。**（无需修改）**

开发者的所有工作都将聚焦在 `mcp_server/` 目录中。

## 快速开始

### 环境准备

**1. Python 环境 (3.9+)**

```bash
# 创建并激活虚拟环境 (推荐)
python -m venv venv
# Windows
.\venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

**2. R 环境**

- 确保已安装 R，并且 `Rscript` 命令在系统的 `PATH` 中。
- 安装所需的 R 包：

```R
# 在 R 控制台中运行
install.packages(c('mcptools', 'ellmer', 'readr', 'dplyr', 'ggplot2', 'broom', 'jsonlite'))
```

### 配置

1.  在项目根目录创建一个 `.env` 文件。
2.  在文件中配置 `OPENAI_API_KEY`。

```ini
# .env

OPENAI_API_KEY="sk-YourKeyHere"

# (可选) 如果 Rscript 不在默认路径，请指定其完整路径
# RSCRIPT_BIN="C:/Program Files/R/R-4.x.x/bin/Rscript.exe"
```

### 运行项目

本项目支持两种运行模式：

**1. Gradio Web 界面 (推荐)**

```bash
python main.py
```

启动后，浏览器将自动打开 Web 界面，您可以在此上传数据并提出分析需求。

**2. 命令行 (CLI) 模式**

```bash
python main.py --mode cli
```

此模式允许您直接在终端中与智能体交互。

## 开发工作流：添加新工具

假设我们需要添加一个**逻辑回归 (Logistic Regression)** 工具。

### 第一步：编写 R 函数

在 `mcp_server/r_tools/` 目录下创建一个新的 R 文件，例如 `logistic_tool.R`。函数应尽可能独立，并返回易于解析的 `list` 或 `data.frame`。

```R
# mcp_server/r_tools/logistic_tool.R

suppressPackageStartupMessages({library(readr); library(broom)})

tool_logistic_model <- function(path, formula_str, out_dir=".") {
  df <- readr::read_csv(path, show_col_types = FALSE)
  fit <- stats::glm(stats::as.formula(formula_str), data = df, family = "binomial")
  
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  
  # 返回一个包含整洁结果的列表
  list(
    glance = broom::glance(fit),
    tidy   = broom::tidy(fit, exponentiate = TRUE) # 获取优势比 (OR)
  )
}
```

### 第二步：注册 R 工具

在 `mcp_server/r_mcp_server.R` 文件中，将新工具告知 AI。

```R
# mcp_server/r_mcp_server.R

# ... (其他 library)

# 1. 加载新工具文件
tool_dir <- "mcp_server/r_tools"
source(file.path(tool_dir, "eda_tools.R"))
# ...
source(file.path(tool_dir, "logistic_tool.R")) # <-- 添加这一行

# ... (其他工具定义)

# 2. 将函数包装为 AI 可理解的工具
r_logistic_model <- ellmer::tool(
  tool_logistic_model,
  name = "r_logistic_model",
  description = "拟合逻辑回归模型，返回模型摘要。",
  arguments = list(
    path        = ellmer::type_string("CSV 文件的路径。"),
    formula_str = ellmer::type_string('R 语言公式, 例如 "y ~ x1 + x2"。')
  )
)

# 3. 将新工具添加到服务器的工具列表
mcptools::mcp_server(tools = list(
  r_eda, 
  r_linear_model,
  # ...
  r_logistic_model # <-- 添加新工具
))
```

### 第三步：测试新工具

重启项目 (`python main.py`)，AI 智能体现在就可以使用 `r_logistic_model` 工具了。

您可以向它提问：“请使用 `data.csv` 数据集，拟合一个逻辑回归模型，公式为 `response ~ age + gender`。”

## 项目结构

```
.
├── agent/                  # AI 智能体 (无需修改)
├── mcp_client/             # Python-R 客户端 (无需修改)
├── mcp_server/             # 主要工作区
│   ├── r_tools/            # (核心) 在此编写/修改 R 工具
│   └── r_mcp_server.R      # (核心) 在此注册 R 工具
├── tools/                  # Python 端工具 (无需修改)
├── ui/                     # Gradio Web 界面 (无需修改)
├── .env                    # API 密钥和配置
├── main.py                 # 项目主入口
└── requirements.txt        # Python 依赖
```

## 展望与未来改进

虽然本项目展示了自动化数据分析的强大潜力，但在广度和深度上仍有巨大的拓展空间。

### 1. 分析方法的深化
-   **引入机器学习模型**: 目前主要依赖传统的统计检验和线性回归。未来可以引入随机森林 (Random Forest) 或 XGBoost，用于更精准地预测未知陨石的分类或质量。
-   **时间序列预测**: 针对陨石发现的时间趋势，可以使用 ARIMA 或 Prophet 模型进行未来几十年发现率的预测，辅助科考规划。

### 2. 数据的多维融合
-   **地质与气象数据**: 结合发现地的地质类型（如沙漠、冰川）和气候数据，分析环境对陨石保存（风化程度）的影响。
-   **天文学关联**: 将陨石数据与近地小行星光谱数据交叉验证，探索特定轨道与特定陨石种类的母体联系。

### 3. 系统架构的升级
-   **多智能体协作 (Multi-Agent)**: 引入"审核员 Agent"，负责对分析师 Agent 的代码和结论进行 Peer Review，进一步提高分析的严谨性。
-   **交互式可视化**: 将静态 PNG 图表升级为 Plotly 或 Shiny 交互式图表，允许用户缩放地图、筛选数据点，获得更直观的探索体验。

本项目期待成为连接**人工智能**与**严谨统计科学**的桥梁，为未来的科研自动化探索更多可能性。