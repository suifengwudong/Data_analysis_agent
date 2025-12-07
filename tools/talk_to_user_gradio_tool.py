"""
Gradio 版本的用户交互工具
"""
import logging

logger = logging.getLogger(__name__)


class UserInteractionNeeded(Exception):
    """agent 需要用户输入时抛出的异常"""
    def __init__(self, message: str):
        self.message = message
        super().__init__(message)


class TalkToUserGradio:
    """Gradio 环境下的用户交互工具"""
    
    def __call__(self, message: str) -> str:
        """
        向用户提问（通过抛出异常让 Gradio 处理）
        
        Args:
            message: 要问用户的问题
            
        Raises:
            UserInteractionNeeded: 暂停执行，等待用户输入
        """
        logger.info(f"Agent asking user: {message}")
        raise UserInteractionNeeded(message)