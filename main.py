"""
R 数据分析智能体系统 - 主程序
支持 CLI 和 Gradio 两种运行模式（默认 Gradio）
"""
from dotenv import load_dotenv, find_dotenv
_ = load_dotenv(find_dotenv(filename=".env", usecwd=True))

import os
import sys
import logging
import argparse
import tempfile
from pathlib import Path
from mcp_client.client import MCPClient
from agent.data_analysis_agent import DataAnalysisAgent

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def create_agent(working_directory: str, use_gradio: bool = True):
    """
    创建数据分析智能体
    
    Args:
        working_directory: 工作目录
        use_gradio: 是否使用 Gradio 模式（默认 True）
        
    Returns:
        (agent, r_client) 元组
    """
    print("\n" + "="*70)
    print("R 数据分析智能体系统 - 初始化")
    print("="*70)
    
    print("\n[1/3] 检查环境配置...")
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("  ✗ 错误: 未设置 OPENAI_API_KEY 环境变量!")
        print("  请在 .env 文件中设置: OPENAI_API_KEY=your-key-here")
        sys.exit(1)
    print("  ✓ API Key 已设置")
    print(f"  ✓ 工作目录: {working_directory}")
    print(f"  ✓ 运行模式: {'Gradio Web 界面' if use_gradio else 'CLI 命令行'}")
    
    print("\n[2/3] 启动 R MCP 服务器...")
    try:
        rscript = os.getenv("RSCRIPT_BIN") or "Rscript"
        r_client = MCPClient(
            server_command=[rscript, "mcp_server/r_mcp_server.R"]
        )
        
        tools = r_client.get_openai_tools()
        print(f"  ✓ R 服务器已启动")
        print(f"  ✓ 加载了 {len(tools)} 个 R 分析工具:")
        for i, t in enumerate(tools, 1):
            name = t["function"]["name"]
            desc = t["function"]["description"].split('\n')[0][:50]
            print(f"     {i}. {name} - {desc}...")
            
    except Exception as e:
        print(f"  ✗ R 服务器启动失败: {e}")
        print("\n可能的原因:")
        print("  1. 未安装 R 或 Rscript 不在 PATH 中")
        print("  2. 未安装必要的 R 包")
        print("  3. mcp_server/r_mcp_server.R 文件不存在")
        sys.exit(1)
    
    print("\n[3/3] 创建数据分析 Agent...")
    agent = DataAnalysisAgent(
        api_key=api_key,
        r_client=r_client,
        working_directory=working_directory,
        model="gpt-4o",
        max_iterations=20,
        use_gradio=use_gradio
    )
    print("  ✓ Agent 已就绪")
    
    print("\n" + "="*70)
    print("✅ 初始化完成！")
    print("="*70 + "\n")
    
    return agent, r_client


def run_cli_mode(agent):
    """CLI 命令行模式"""
    print("="*70)
    print("CLI 模式 - 命令行交互")
    print("="*70)
    print(" 提示:")
    print("  - 直接输入你的数据分析需求")
    print("  - 输入 'exit' 或 'quit' 退出")
    print("  - 输入 'reset' 重置对话")
    print("="*70 + "\n")
    
    while True:
        try:
            user_input = input("\n👤 你的需求 > ").strip()
            
            # 处理退出命令
            if user_input.lower() in ['exit', 'quit', 'q']:
                print("\n 再见！")
                break
            
            # 处理重置命令
            if user_input.lower() in ['reset', 'clear']:
                agent.reset()
                print("\n 对话已重置")
                continue
            
            # 忽略空输入
            if not user_input:
                continue
            
            # 分析请求
            print("\n Agent 分析中...\n")
            result = agent.analyze(user_input)
            
            # 显示结果
            print("\n" + "-"*70)
            print(" 分析结果:")
            print("-"*70)
            print(result)
            print("-"*70)
            
        except KeyboardInterrupt:
            print("\n\n 再见！")
            break
        except Exception as e:
            print(f"\n 错误: {e}")
            logger.error("CLI error", exc_info=True)


def run_gradio_mode(agent, working_directory):
    """Gradio Web 界面模式"""
    from ui.gradio_ui import GradioUI
    
    print("="*70)
    print("启动 Gradio Web 界面...")
    print("="*70)
    print(f"工作目录: {working_directory}")
    print("服务器将在启动后自动打开浏览器")
    print("="*70 + "\n")
    
    try:
        GradioUI(
            agent=agent,
            file_upload_folder=working_directory
        ).launch(
            share=False  # 只保留 share 参数，其他使用默认值
        )
    except Exception as e:
        logger.error(f"Gradio launch error: {e}", exc_info=True)
        print(f"\n Gradio 启动失败: {e}")
        sys.exit(1)


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="R 数据分析智能体系统 (OpenAI GPT-4o + R MCP)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python main.py                          # 启动 Gradio Web 界面（默认）
  python main.py --mode cli               # 启动 CLI 命令行模式
  python main.py --working_directory ./my_data  # 指定工作目录
        """
    )
    
    parser.add_argument(
        "--mode",
        type=str,
        default="gradio",
        choices=["gradio", "cli"],
        help="运行模式: gradio (Web界面，默认) 或 cli (命令行)",
    )
    
    parser.add_argument(
        "--working_directory",
        type=str,
        default=None,
        help="工作目录路径（存储上传文件和分析结果）",
    )
    
    args = parser.parse_args()
    
    # 设置工作目录
    if args.working_directory is None:
        base_temp_dir = "temp_files"
        Path(base_temp_dir).mkdir(parents=True, exist_ok=True)
        args.working_directory = tempfile.mkdtemp(
            dir=base_temp_dir,
            prefix=f"r_analysis_{args.mode}_"
        )
    else:
        Path(args.working_directory).mkdir(parents=True, exist_ok=True)
    
    args.working_directory = os.path.abspath(args.working_directory)
    
    # 创建 agent
    agent, r_client = create_agent(
        working_directory=args.working_directory,
        use_gradio=(args.mode == "gradio")
    )
    
    try:
        # 根据模式启动
        if args.mode == "cli":
            run_cli_mode(agent)
        else:
            run_gradio_mode(agent, args.working_directory)
    
    except KeyboardInterrupt:
        print("\n\n 程序已终止")
    
    finally:
        # 清理资源
        print("\n🧹 清理资源...")
        try:
            r_client.close()
            print("  ✓ R 服务器已关闭")
        except:
            pass


if __name__ == "__main__":
    main()