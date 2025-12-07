"""
Gradio Web 界面 - 带文件浏览和预览功能
"""
import os
import re
import shutil
import logging
from pathlib import Path
import pandas as pd
import gradio as gr
from tools.talk_to_user_gradio_tool import UserInteractionNeeded

logger = logging.getLogger(__name__)


class GradioUI:
    """R数据分析系统的 Gradio 界面"""
    
    def __init__(self, agent, file_upload_folder: str):
        """初始化 Gradio 界面"""
        self.agent = agent
        self.file_upload_folder = file_upload_folder
        Path(file_upload_folder).mkdir(parents=True, exist_ok=True)
        logger.info(f"GradioUI initialized with folder: {file_upload_folder}")
    
    def upload_file(self, file, file_log):
        """处理文件上传"""
        if file is None:
            return gr.update(value="未选择文件"), file_log, self._get_file_list_display()
        
        try:
            # 获取文件路径（支持多种 Gradio 版本）
            src_path = None
            orig_name = None
            
            if isinstance(file, str):
                src_path = file
                orig_name = os.path.basename(file)
            elif hasattr(file, "path"):
                src_path = file.path
                orig_name = getattr(file, "orig_name", os.path.basename(file.path))
            elif hasattr(file, "name"):
                src_path = file.name
                orig_name = getattr(file, "orig_name", os.path.basename(file.name))
            
            if not src_path or not os.path.exists(src_path):
                return gr.update(value="无法识别文件"), file_log, self._get_file_list_display()
            
            # 清理文件名并保存
            if not orig_name:
                orig_name = os.path.basename(src_path)
            
            sanitized_name = re.sub(r'[^\w\-.]', "_", orig_name)
            dst_path = os.path.join(self.file_upload_folder, sanitized_name)
            
            # 检查是否已存在
            if dst_path in file_log:
                return gr.update(value=f"文件已存在: {sanitized_name}"), file_log, self._get_file_list_display()
            
            # 复制文件
            shutil.copy2(src_path, dst_path)
            file_size = os.path.getsize(dst_path)
            logger.info(f"File uploaded: {sanitized_name} ({file_size} bytes)")
            
            return (
                gr.update(value=f"已上传: {sanitized_name} ({file_size / 1024:.1f} KB)"),
                file_log + [dst_path],
                self._get_file_list_display()
            )
        
        except Exception as e:
            logger.error(f"Upload error: {e}", exc_info=True)
            return gr.update(value=f"上传失败: {str(e)}"), file_log, self._get_file_list_display()
    
    def _get_file_list_display(self):
        """获取工作目录中的所有文件（用于显示）"""
        try:
            files = []
            if os.path.exists(self.file_upload_folder):
                for item in sorted(os.listdir(self.file_upload_folder)):
                    item_path = os.path.join(self.file_upload_folder, item)
                    if os.path.isfile(item_path):
                        size = os.path.getsize(item_path)
                        files.append([item, f"{size / 1024:.1f} KB"])
            return files
        except Exception as e:
            logger.error(f"Error listing files: {e}")
            return []
    
    def refresh_files(self):
        """刷新文件列表"""
        return self._get_file_list_display()
    
    def preview_file(self, filename):
        """根据文件名预览文件"""
        try:
            if not filename or not filename.strip():
                return None, None, gr.update(visible=False), gr.update(visible=False)
            
            filename = filename.strip()
            filepath = os.path.join(self.file_upload_folder, filename)
            
            if not os.path.exists(filepath):
                logger.warning(f"File not found: {filepath}")
                return None, None, gr.update(visible=False), gr.update(visible=False)
            
            # 根据文件类型预览
            ext = os.path.splitext(filename)[1].lower()
            
            # 图片文件
            if ext in ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp']:
                logger.info(f"Previewing image: {filename}")
                return (
                    filepath,
                    None,
                    gr.update(visible=True),
                    gr.update(visible=False)
                )
            
            # CSV 文件
            elif ext in ['.csv', '.tsv']:
                logger.info(f"Previewing CSV: {filename}")
                try:
                    df = pd.read_csv(filepath, nrows=100)
                    return (
                        None,
                        df,
                        gr.update(visible=False),
                        gr.update(visible=True)
                    )
                except Exception as e:
                    logger.error(f"Error reading CSV: {e}")
                    return None, None, gr.update(visible=False), gr.update(visible=False)
            
            # 其他文件类型
            else:
                logger.info(f"File type not supported for preview: {ext}")
                return None, None, gr.update(visible=False), gr.update(visible=False)
        
        except Exception as e:
            logger.error(f"Preview error: {e}", exc_info=True)
            return None, None, gr.update(visible=False), gr.update(visible=False)
    
    def chat_with_agent(self, message, history, file_log, session_state):
        """与 agent 对话"""
        if not message.strip():
            return history, "", self._get_file_list_display()
        
        # 添加用户消息到历史
        history.append({"role": "user", "content": message})
        yield history, "", self._get_file_list_display()
        
        try:
            # 检查是否有待处理的任务
            if session_state.get("pending_task"):
                session_state["pending_task"] = None
                logger.info(f"User answering: {message}")
                full_prompt = message
            else:
                # 新请求
                full_prompt = message
                if file_log:
                    file_list = "\n".join([f"- {os.path.basename(f)}" for f in file_log])
                    full_prompt = f"{message}\n\n工作目录中的可用文件:\n{file_list}"
            
            # 调用 agent 分析
            result = self.agent.analyze(full_prompt)
            
            # 添加响应
            history.append({"role": "assistant", "content": result})
            yield history, "", self._get_file_list_display()
            
        except UserInteractionNeeded as e:
            session_state["pending_task"] = True
            logger.info(f"Agent needs input: {e.message}")
            
            history.append({
                "role": "assistant",
                "content": f"**我需要更多信息:**\n\n{e.message}\n\n*请在下方输入框回答。*"
            })
            yield history, "", self._get_file_list_display()
        
        except Exception as e:
            logger.error(f"Analysis error: {e}", exc_info=True)
            history.append({
                "role": "assistant",
                "content": f"**发生错误:**\n\n```\n{str(e)}\n```"
            })
            yield history, "", self._get_file_list_display()
    
    def reset_session(self, session_state, file_log):
        """重置会话"""
        try:
            # 清空工作目录
            if os.path.exists(self.file_upload_folder):
                for item in os.listdir(self.file_upload_folder):
                    item_path = os.path.join(self.file_upload_folder, item)
                    try:
                        if os.path.isfile(item_path):
                            os.remove(item_path)
                        elif os.path.isdir(item_path):
                            shutil.rmtree(item_path)
                    except Exception as e:
                        logger.warning(f"Could not remove {item_path}: {e}")
            
            # 重置 agent
            self.agent.reset()
            session_state.clear()
            
            logger.info("Session reset")
            return (
                [],
                [],
                gr.update(value=""),
                gr.update(value=None),
                gr.update(value=""),
                self._get_file_list_display(),
                "",
                None,
                None,
                gr.update(visible=False),
                gr.update(visible=False)
            )
        
        except Exception as e:
            logger.error(f"Reset error: {e}")
            return (
                [], [], 
                gr.update(value=""), 
                gr.update(value=None), 
                gr.update(value=f"重置失败: {e}"), 
                self._get_file_list_display(),
                "",
                None, None,
                gr.update(visible=False),
                gr.update(visible=False)
            )
    
    def launch(self, share=False, **kwargs):
        """启动界面"""
        
        with gr.Blocks(theme=gr.themes.Soft(), title="R 数据分析助手") as demo:
            session_state = gr.State({})
            file_log = gr.State([])
            
            gr.Markdown("""
            # R 数据分析智能助手
            
            上传 CSV 数据文件，用自然语言描述分析需求，AI 将调用 R 工具完成数据分析！
            """)
            
            with gr.Row():
                # 左侧：对话区
                with gr.Column(scale=2):
                    chatbot = gr.Chatbot(
                        label="💬 对话历史",
                        type="messages",
                        height=450,
                        show_copy_button=True
                    )
                    
                    with gr.Row():
                        msg_input = gr.Textbox(
                            label="输入消息",
                            placeholder="例如：请对上传的数据进行探索性分析...",
                            lines=2,
                            scale=5
                        )
                    
                    with gr.Row():
                        submit_btn = gr.Button("📤 发送", variant="primary", scale=2)
                        reset_btn = gr.Button("🗑️ 重置会话", variant="stop", scale=1)
                
                # 右侧：文件管理和预览
                with gr.Column(scale=1):
                    gr.Markdown("### 📁 文件上传")
                    
                    file_upload = gr.File(
                        label="上传数据文件",
                        file_types=[".csv", ".xlsx", ".tsv", ".txt"]
                    )
                    
                    upload_status = gr.Textbox(
                        label="上传状态",
                        interactive=False,
                        show_label=False
                    )
                    
                    gr.Markdown("---")
                    gr.Markdown("### 📂 工作目录文件")
                    
                    refresh_btn = gr.Button("🔄 刷新", size="sm")
                    
                    # 文件列表
                    file_list = gr.Dataframe(
                        headers=["文件名", "大小"],
                        datatype=["str", "str"],
                        label="",
                        interactive=False,
                        wrap=True
                    )
                    
                    # 预览文件名输入框
                    gr.Markdown("### 👁️ 文件预览")
                    with gr.Row():
                        preview_filename = gr.Textbox(
                            label="输入文件名预览",
                            placeholder="例如: scatter_age_pts.png",
                            scale=4
                        )
                        preview_btn = gr.Button("👁️", scale=1)
                    
                    # 图片预览
                    image_preview = gr.Image(
                        label="图片预览",
                        visible=False,
                        show_label=True
                    )
                    
                    # CSV 预览
                    csv_preview = gr.Dataframe(
                        label="数据预览 (前100行)",
                        visible=False,
                        wrap=True
                    )
                    
                    gr.Markdown("---")
                    gr.Markdown("### 📖 快速开始")
                    
                    with gr.Accordion("支持的分析", open=False):
                        gr.Markdown("""
                        1. **EDA** - 探索性数据分析
                        2. **回归** - 线性回归建模  
                        3. **可视化** - 图表生成
                        4. **聚类** - K-means 分析
                        5. **假设检验** - 统计检验
                        
                        **提示:** 
                        - 输入文件名点击预览按钮
                        - 支持预览图片(PNG/JPG)和CSV
                        """)
            
            # 事件绑定
            file_upload.change(
                self.upload_file,
                inputs=[file_upload, file_log],
                outputs=[upload_status, file_log, file_list]
            )
            
            refresh_btn.click(
                self.refresh_files,
                outputs=[file_list]
            )
            
            # 预览按钮
            preview_btn.click(
                self.preview_file,
                inputs=[preview_filename],
                outputs=[image_preview, csv_preview, image_preview, csv_preview]
            )
            
            msg_input.submit(
                self.chat_with_agent,
                inputs=[msg_input, chatbot, file_log, session_state],
                outputs=[chatbot, msg_input, file_list]
            )
            
            submit_btn.click(
                self.chat_with_agent,
                inputs=[msg_input, chatbot, file_log, session_state],
                outputs=[chatbot, msg_input, file_list]
            )
            
            reset_btn.click(
                self.reset_session,
                inputs=[session_state, file_log],
                outputs=[
                    chatbot, file_log, msg_input, file_upload, upload_status, 
                    file_list, preview_filename, image_preview, csv_preview, 
                    image_preview, csv_preview
                ]
            )
            
            # 初始加载文件列表
            demo.load(self.refresh_files, outputs=[file_list])
        
        logger.info("Launching Gradio")
        demo.launch(share=share, **kwargs)