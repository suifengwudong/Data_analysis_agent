import logging

logger = logging.getLogger(__name__)


class TalkToUser:
    """命令行环境下的用户交互工具"""
    
    def __call__(self, message: str) -> str:
        """
        向用户提问并等待回答
        
        Args:
            message: 要问用户的问题
            
        Returns:
            用户的回答
        """
        print(f"\n{'='*60}")
        print(f" Agent 需要更多信息:")
        print(f"{'='*60}")
        print(f"{message}\n")
        
        user_response = input("你的回答: ").strip()
        
        if not user_response:
            user_response = "继续"
        
        logger.info(f"User response: {user_response}")
        return user_response