"""
数据分析智能体 - 使用 OpenAI GPT-4o
支持 CLI 和 Gradio 两种交互模式
"""

import json
import logging
from typing import Dict, Any, Optional
from openai import OpenAI
import os
import re

logger = logging.getLogger(__name__)


class DataAnalysisAgent:
    """数据分析智能体"""
    
    def __init__(self, 
                 api_key: str, 
                 r_client, 
                 working_directory: str,
                 model: str = "gpt-4o", 
                 max_iterations: int = 20,
                 use_gradio: bool = False):
        """
        初始化智能体
        
        Args:
            api_key: OpenAI API密钥
            r_client: R工具客户端
            working_directory: 工作目录
            model: 使用的模型
            max_iterations: 最大迭代次数
            use_gradio: 是否在 Gradio 模式下运行
        """
        self.client = OpenAI(api_key=api_key)
        self.r_client = r_client
        self.working_directory = working_directory
        self.model = model
        self.max_iterations = max_iterations
        self.use_gradio = use_gradio
        
        # 根据模式选择交互工具
        if use_gradio:
            from tools.talk_to_user_gradio_tool import TalkToUserGradio
            self.talk_tool = TalkToUserGradio()
        else:
            from tools.talk_to_user_tool import TalkToUser
            self.talk_tool = TalkToUser()
        
        # 对话历史
        self.messages = []
        
        # 用于存储列名映射
        self.column_map: Dict[str, str] = {}
        
        # 用于存储待处理的 tool_call（当需要用户输入时）
        self.pending_tool_call = None
        
        logger.info(f"Agent initialized: model={model}, mode={'Gradio' if use_gradio else 'CLI'}, working_dir={working_directory}")
    
    def _get_system_prompt(self) -> str:
        """构建系统提示"""
        return f"""你是一个专业的数据分析师助手，专门使用 R 工具完成数据分析任务。

**工作目录**: {self.working_directory}

**可用的 R 分析工具**:

1. **r_eda** - 探索性数据分析
   - 数据形状、缺失值检查
   - 数值变量统计摘要
   - 相关性矩阵（可选指定变量）

2. **r_linear_model** - 线性回归建模
   - 拟合线性模型
   - 生成诊断图（残差图、QQ图等）
   - 输出模型摘要和诊断 PNG

3. **r_visualize** - 数据可视化
   - 散点图 (scatter)
   - 直方图 (histogram)
   - 箱线图 (boxplot)
   - 保存为 PNG 文件

4. **r_clustering** - K-means 聚类
   - 对指定数值变量聚类
   - 输出带聚类标签的 CSV

5. **r_hypothesis_test** - 统计假设检验
   - t 检验 (t_test)
   - 相关性检验 (correlation)

6. **talk_to_user** - 向用户提问
   - 当分析需求不明确时使用
   - 获取更多信息或澄清需求

**工作流程**:

1. **理解需求**: 仔细分析用户的分析需求
2. **必要提问**: 如果需求不明确（如缺少文件路径、变量名、模型公式等），使用 `talk_to_user` 主动询问
3. **制定计划**: 规划清晰的分析步骤
4. **执行分析**: 按步骤调用 R 工具
5. **解释结果**: 用通俗语言解释统计结果
6. **提供建议**: 给出可操作的业务洞察

**重要原则**:

- 所有统计计算必须由 R 工具完成（不要自己计算）
- 先进行 EDA 了解数据，再进行建模
- 为结果创建可视化图表
- 用清晰、通俗的语言解释统计概念
- 如果用户需求模糊或不完整，主动使用 talk_to_user 询问
- 提供可操作的业务建议

**文件路径规则**:
- 用户上传的文件会保存在工作目录 `{self.working_directory}` 中
- 调用 R 工具时，直接使用文件名即可（如 "nba_player.csv"）
- 输出文件也会保存在同一目录

开始分析吧！"""
    
    def _get_tools_with_talk(self) -> list:
        """获取包含 talk_to_user 的工具列表"""
        tools = self.r_client.get_openai_tools()
        
        # 添加 talk_to_user 工具
        talk_tool_spec = {
            "type": "function",
            "function": {
                "name": "talk_to_user",
                "description": "向用户提问以获取更多信息或澄清需求。当分析需求不明确（如缺少文件路径、变量名、模型参数等）时使用此工具。",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "message": {
                            "type": "string",
                            "description": "要问用户的问题。应该清晰、具体，让用户容易回答。"
                        }
                    },
                    "required": ["message"]
                }
            }
        }
        
        tools.append(talk_tool_spec)
        return tools
    
    def _update_formula_with_column_map(self, formula: str) -> str:
        """使用列名映射更新公式字符串"""
        if not self.column_map:
            return formula
        
        logger.info(f"Updating formula '{formula}' with column map: {self.column_map}")
        
        # 为了避免错误替换（例如，用 'var_1' 替换 'var_10' 中的 'var_1'），
        # 我们按键的长度降序排序
        sorted_map = sorted(self.column_map.items(), key=lambda item: len(item[0]), reverse=True)
        
        for old_name, new_name in sorted_map:
            # 使用正则表达式确保只替换完整的单词
            # 这可以防止 'year' 被 'new_year' 中的 'year' 替换
            # `\b` 是一个词边界
            pattern = r'\b' + re.escape(old_name) + r'\b'
            formula = re.sub(pattern, new_name, formula)
            
        logger.info(f"Updated formula: '{formula}'")
        return formula

    def analyze(self, user_request: str) -> str:
        """
        执行数据分析任务
        
        Args:
            user_request: 用户的分析需求或对 agent 问题的回答
            
        Returns:
            分析结果摘要
        """
        logger.info(f"Analyzing: {user_request[:100]}...")
        
        # 检查是否是回答之前的 talk_to_user 问题
        if self.pending_tool_call is not None:
            # 用户在回答之前的问题，将回答添加为工具调用结果
            tool_call_id = self.pending_tool_call
            self.pending_tool_call = None
            
            # 添加工具调用结果
            self.messages.append({
                "role": "tool",
                "tool_call_id": tool_call_id,
                "content": user_request  # 用户的回答就是工具调用的结果
            })
            
            logger.info(f"Added user response as tool result for call_id: {tool_call_id}")
        else:
            # 初始化对话历史（如果是新会话）
            if not self.messages:
                self.messages = [
                    {"role": "system", "content": self._get_system_prompt()},
                ]
            
            # 添加用户消息
            self.messages.append({"role": "user", "content": user_request})
        
        # 智能体循环
        for iteration in range(self.max_iterations):
            logger.info(f"=== Iteration {iteration + 1}/{self.max_iterations} ===")
            
            try:
                # 调用 GPT-4o
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=self.messages,
                    tools=self._get_tools_with_talk(),
                    tool_choice="auto",
                    temperature=0.1
                )
                
                assistant_message = response.choices[0].message
                
                # 检查是否需要调用工具
                if assistant_message.tool_calls:
                    # 添加助手消息
                    self.messages.append({
                        "role": "assistant",
                        "content": assistant_message.content,
                        "tool_calls": [
                            {
                                "id": tc.id,
                                "type": "function",
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments
                                }
                            }
                            for tc in assistant_message.tool_calls
                        ]
                    })
                    
                    # 执行所有工具调用
                    for tool_call in assistant_message.tool_calls:
                        function_name = tool_call.function.name
                        function_args = json.loads(tool_call.function.arguments)
                        
                        logger.info(f"Calling tool: {function_name}")
                        logger.debug(f"Arguments: {json.dumps(function_args, indent=2)}")
                        
                        # 特殊处理 talk_to_user
                        if function_name == "talk_to_user":
                            message = function_args.get("message", "")
                            # 保存 tool_call_id，等待用户回答
                            self.pending_tool_call = tool_call.id
                            # 抛出异常让 Gradio 处理（或在 CLI 中等待输入）
                            result = self.talk_tool(message)
                            # 如果是 CLI 模式，会直接返回结果
                            # 添加工具结果
                            self.messages.append({
                                "role": "tool",
                                "tool_call_id": tool_call.id,
                                "content": result
                            })
                            self.pending_tool_call = None
                        else:
                            # 如果有列名映射，更新公式参数
                            if "formula_str" in function_args and self.column_map:
                                function_args["formula_str"] = self._update_formula_with_column_map(
                                    function_args["formula_str"]
                                )

                            # 调用 R 工具
                            # 确保路径参数使用工作目录
                            if "path" in function_args:
                                path = function_args["path"]
                                if not os.path.isabs(path):
                                    function_args["path"] = os.path.join(
                                        self.working_directory, 
                                        os.path.basename(path)
                                    )
                            
                            # 统一输出目录到工作目录根目录
                            if "out_dir" in function_args:
                                if not function_args.get("out_dir"):
                                    function_args["out_dir"] = self.working_directory
                                elif not os.path.isabs(function_args["out_dir"]):
                                    function_args["out_dir"] = self.working_directory
                            
                            if "output_path" in function_args:
                                if not function_args.get("output_path"):
                                    # 生成一个有意义的文件名
                                    base_name = f"{function_name}_{os.urandom(4).hex()}.png"
                                    function_args["output_path"] = os.path.join(
                                        self.working_directory,
                                        base_name
                                    )
                                elif not os.path.isabs(function_args["output_path"]):
                                    function_args["output_path"] = os.path.join(
                                        self.working_directory,
                                        os.path.basename(function_args["output_path"])
                                    )
                            
                            if "out_path" in function_args:
                                if not function_args.get("out_path"):
                                    function_args["out_path"] = os.path.join(
                                        self.working_directory,
                                        "clustered_data.csv"
                                    )
                                elif not os.path.isabs(function_args["out_path"]):
                                    function_args["out_path"] = os.path.join(
                                        self.working_directory,
                                        os.path.basename(function_args["out_path"])
                                    )
                            
                            result_str = self.r_client.call_tool(function_name, function_args)
                            logger.info(f"Tool result string: {result_str[:200]}...")

                            try:
                                # 尝试将结果解析为 JSON
                                result_data = json.loads(result_str)
                            except json.JSONDecodeError:
                                # 如果解析失败，则将其视为普通字符串
                                result_data = result_str
                            
                            # 如果是 r_clean_data 并且返回了 column_map，则存储它
                            if function_name == "r_clean_data" and isinstance(result_data, dict) and "column_map" in result_data:
                                new_map = result_data.get("column_map")
                                if new_map:
                                    logger.info(f"Received new column map: {new_map}")
                                    self.column_map.update(new_map)
                                    logger.info(f"Updated agent's column map: {self.column_map}")
                            
                            # 添加工具结果
                            self.messages.append({
                                "role": "tool",
                                "tool_call_id": tool_call.id,
                                "content": result_str # 将原始JSON字符串传递给LLM
                            })
                
                else:
                    # 没有工具调用,任务完成
                    final_response = assistant_message.content or "分析完成"
                    logger.info("Analysis completed successfully")
                    return final_response
                    
            except Exception as e:
                # 如果是 UserInteractionNeeded，直接抛出让 Gradio 处理
                if e.__class__.__name__ == "UserInteractionNeeded":
                    raise
                
                logger.error(f"Error in iteration {iteration + 1}: {e}", exc_info=True)
                return f"分析过程中出现错误:\n\n```\n{str(e)}\n```"
        
        return "分析未完成（达到最大迭代次数）。请尝试简化需求或分步骤提问。"
    
    def reset(self):
        """重置对话历史"""
        self.messages = []
        self.pending_tool_call = None
        logger.info("Agent memory reset")