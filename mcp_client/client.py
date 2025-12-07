"""
简单的 R MCP 客户端
解决协议版本不匹配问题
"""
import os
import json
import subprocess
import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class MCPClient:
    """简单的 R MCP 客户端 - 直接 JSON-RPC 通信"""
    
    def __init__(self, 
                 server_command: Optional[List[str]] = None,
                 timeout: float = 30.0):
        """
        初始化客户端 - 接口兼容原 MCPClient
        
        Args:
            server_command: R 服务器启动命令
            timeout: 超时时间（秒）
        """
        rscript = os.getenv("RSCRIPT_BIN") or "Rscript"
        self.server_command = server_command or [rscript, "mcp_server/r_mcp_server.R"]
        self.timeout = timeout
        
        self.proc = None
        self.request_id = 0
        self._tools_cache = None
        
        logger.info(f"MCP Client initialized: {' '.join(self.server_command)}")
    
    def _start_server(self):
        """启动 R 服务器"""
        if self.proc is not None:
            return
        
        logger.info("Starting R MCP server...")
        self.proc = subprocess.Popen(
            self.server_command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=os.environ.copy()
        )
        
        # 等待启动
        import time
        time.sleep(1)
        
        # 检查进程
        if self.proc.poll() is not None:
            raise Exception(f"R server failed to start (exit code: {self.proc.returncode})")
        
        logger.info(f"✓ R server started (PID: {self.proc.pid})")
        
        # 初始化
        self._initialize()
    
    def _send_request(self, method: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """发送 JSON-RPC 请求"""
        if self.proc is None:
            self._start_server()
        
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }
        
        request_str = json.dumps(request) + "\n"
        logger.debug(f"Sending: {method}")
        
        self.proc.stdin.write(request_str)
        self.proc.stdin.flush()
        
        # 读取响应
        response_str = self.proc.stdout.readline()
        if not response_str:
            raise Exception(f"No response for {method}")
        
        response = json.loads(response_str)
        
        if "error" in response:
            raise Exception(f"RPC error: {response['error']}")
        
        return response
    
    def _initialize(self):
        """初始化会话"""
        logger.info("Initializing session...")
        response = self._send_request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "simple-python-client",
                    "version": "1.0.0"
                }
            }
        )
        logger.info("✓ Session initialized")
    
    def get_openai_tools(self) -> List[Dict[str, Any]]:
        """获取 OpenAI 格式的工具列表"""
        if self._tools_cache is None:
            logger.info("Loading tools...")
            response = self._send_request("tools/list")
            tools = response.get("result", {}).get("tools", [])
            
            # 过滤掉有问题的工具（list_r_sessions, select_r_session）
            # 这些工具的 schema 不完整，OpenAI API 会拒绝
            filtered_tools = [
                tool for tool in tools 
                if tool["name"] not in ["list_r_sessions", "select_r_session"]
            ]
            
            # 转换为 OpenAI 格式
            self._tools_cache = [
                {
                    "type": "function",
                    "function": {
                        "name": tool["name"],
                        "description": tool.get("description", ""),
                        "parameters": tool.get("inputSchema", {})
                    }
                }
                for tool in filtered_tools
            ]
            
            logger.info(f"✓ Loaded {len(self._tools_cache)} tools (filtered from {len(tools)} total)")
        
        return self._tools_cache
    
    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """调用工具"""
        logger.info(f"Calling tool: {tool_name}")
        logger.debug(f"Arguments: {json.dumps(arguments)}")
        
        response = self._send_request(
            "tools/call",
            {
                "name": tool_name,
                "arguments": arguments
            }
        )
        
        result = response.get("result", {})
        
        # 提取 content
        if "content" in result:
            contents = []
            for content in result["content"]:
                if content.get("type") == "text":
                    contents.append(content["text"])
            
            # 合并所有文本内容
            combined = "\n".join(contents) if contents else ""
            
            logger.info(f"✓ Tool {tool_name} completed")
            return combined
        
        # 没有 content，返回整个 result
        return json.dumps(result)
    
    def close(self):
        """关闭连接"""
        if self.proc:
            logger.info("Closing R server...")
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()
            self.proc = None
            logger.info("✓ R server closed")
    
    def __del__(self):
        """析构"""
        try:
            self.close()
        except:
            pass