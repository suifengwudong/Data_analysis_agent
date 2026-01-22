# R 数据分析智能体框架

一个基于 Python 和 R 的 AI 智能体框架，旨在通过调用自定义的 R 工具来完成复杂的数据分析任务。

## 目录

- [R 数据分析智能体框架](#r-数据分析智能体框架)
  - [目录](#目录)
  - [项目简介](#项目简介)
  - [项目实战：陨石数据分析](#项目实战陨石数据分析)
    - [1. 问题定义](#1-问题定义)
    - [3. 数据分类标准 (Scientific Classification)](#3-数据分类标准-scientific-classification)
    - [4. 智能体构建与驱动机制](#4-智能体构建与驱动机制)
      - [4.1 智能体构建方法论 (Construction Methodology)](#41-智能体构建方法论-construction-methodology)
      - [4.2 智能体驱动策略 (Utilization via `test/prompt.md`)](#42-智能体驱动策略-utilization-via-testpromptmd)
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

### 3. 数据分类标准 (Scientific Classification)

原始数据中的 `recclass` 字段混合了化学群和岩石学类型，包含 400+ 种详细类别。为了支持高层次的统计分析，我们在清洗阶段 (`r_clean_data`) 引入了自动映射逻辑，生成 `scientific_type` 字段：

| 科学大类 (Scientific Type) | 包含的原始分类 (recclass 关键词) | 占比 (约) |
| :--- | :--- | :--- |
| **Chondrite (Ordinary)** | L, H, LL, Ordinary, OC | > 85% |
| **Chondrite (Carbonaceous)** | CI, CM, CO, CV, CK, CR, CB, CH, Carbonaceous | ~ 4% |
| **Chondrite (Enstatite)** | EH, EL, Enstatite | < 1% |
| **Achondrite** | HED (Howardite, Eucrite, Diogenite), Aubrite, Ureilite, Angrite, Lunar, Martian | ~ 5% |
| **Iron** | Iron, IAB, IIAB, IIIAB, IVA, IVB | ~ 4% |
| **Stony-Iron** | Pallasite, Mesosiderite, Stony-Iron | < 1% |
| **Stony (Other/Ungrouped)** | 其他未归类石陨石 | < 1% |

### 4. 智能体构建与驱动机制

本项目展示了如何“构建”一个能够执行复杂科学任务的 AI Agent，并阐述了如何通过 System Prompt 来“驱动”它。

#### 4.1 智能体构建方法论 (Construction Methodology)

为了实现严谨且自动化的分析，我们采用了 **"Python 编排 + R 计算"** 的双层架构：

*   **大脑层 (Python/LLM)**
    *   **核心逻辑**: `agent/data_analysis_agent.py` 封装了 OpenAI API 调用。它不仅仅是简单的问答，而是一个能够维护会话状态、解析工具调用请求、并处理 R 脚本执行结果的闭环系统。
    *   **自适应纠错**: 赋予 Agent 读取工具定义的能力。当遇到 R 运行时错误（如“列名不存在”），Agent 能够读取元数据 (`r_eda`)，理解错误原因，并自主修正参数再次尝试。
    *   **上下文管理**: Agent 会维护 chat history，确保在 Module 5 进行回归分析时，依然“记得” Module 1 中清洗过的数据路径。

*   **执行层 (R MCP Server)**
    *   **原子化工具**: 我们将 `dplyr`, `ggplot2`, `stats` 等 R 包的核心功能封装为无状态的原子函数（如 `r_clean_data`, `r_clustering`）。
    *   **JSON 通信**: R 函数接收 JSON 格式化参数，返回 JSON 结果或文件路径，确保跨语言交互的稳定性。

#### 4.2 智能体驱动策略 (Utilization via `test/prompt.md`)

`test/prompt.md` 不仅仅是一个提示词，它是智能体的 **标准作业程序 (SOP)**。我们通过以下策略利用智能体实现既定目标：

1.  **角色沉浸 (Role Definition)**:
    *   定义 Agent 为 **"陨石数据高级分析师"**，并确立 **"数据说话"** 和 **"稳健统计"** 两大核心哲学，明确要求“所有结论必须由 P 值和图表支撑”，从而避免 AI 产生幻觉或空泛的结论。

2.  **强制性思维链 (Structured Chain of Thought)**:
    *   我们将复杂的分析任务拆解为 **6 个模块 (Modules 0-5)**，强制 Agent 按顺序执行。
    *   **Module 0 (Data Prep)**: 预置严格的清洗规则（如 Log10 变换），解决数据右偏问题。
    *   **Module 1-3 (EDA & Test)**: 引导 Agent 从“发现模式”、“时间趋势”、“种类质量”三个维度进行可视化探索和假设检验。
    *   **Module 4-5 (Advanced Modeling)**: 指导 Agent 进行带权重的 K-Means 聚类和含交互项的 GLM 回归，挖掘深层规律。

3.  **结果导向 (Output Requirements)**:
    *   Prompts 中明确指定了每个模块所需的 **可视化动作** (如 `boxplot`, `kde`, `map`) 和 **统计验证方法** (如 `Wilcoxon`, `KS-Test`)，确保产出符合学术标准。

通过这种 **"强逻辑 Prompt + 强能力 Tool"** 的组合，我们成功让通用大模型表现出了领域专家的分析能力。

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