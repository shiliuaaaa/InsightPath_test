import unittest
from unittest.mock import patch, MagicMock
from src.client.deepseek_client import ask_deepseek
import os

class TestDeepSeekClient(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # 1. 模拟环境变量中的 API Key，确保代码中检查 Key 的逻辑通过
        os.environ["DEEPSEEK_API_KEY"] = "sk-mock-key-for-test"

    @classmethod
    def tearDownClass(cls):
        # 清理环境变量
        if "DEEPSEEK_API_KEY" in os.environ:
            del os.environ["DEEPSEEK_API_KEY"]

    @patch("src.Agent.deepseek_client.OpenAI")
    def test_ask_deepseek_basic(self, MockOpenAI):
        """测试基本的提问流程：模拟 API 返回固定回复"""
        # --- Arrange (准备) ---
        # 模拟 Client 实例
        mock_client_instance = MockOpenAI.return_value
        # 模拟 API 响应结构
        mock_response = MagicMock()
        mock_response.choices[0].message.content = "This is a mock response from DeepSeek."
        
        # 配置调用链 client.chat.completions.create -> 返回 mock_response
        mock_client_instance.chat.completions.create.return_value = mock_response

        # --- Act (执行) ---
        user_query = "Hello!"
        result = ask_deepseek(user_query)

        # --- Assert (断言) ---
        self.assertEqual(result, "This is a mock response from DeepSeek.")
        
        # 验证调用参数是否正确 (包含了 system prompt 和 user prompt)
        mock_client_instance.chat.completions.create.assert_called_once()
        call_args = mock_client_instance.chat.completions.create.call_args
        
        # 检查发给 API 的 messages 列表
        sent_messages = call_args[1]['messages']
        self.assertEqual(len(sent_messages), 2)
        self.assertEqual(sent_messages[0]['role'], 'system')
        self.assertEqual(sent_messages[1]['role'], 'user')
        self.assertEqual(sent_messages[1]['content'], 'Hello!')

    @patch("src.Agent.deepseek_client.OpenAI")
    def test_ask_deepseek_with_history(self, MockOpenAI):
        """测试带历史记录的提问流程"""
        # --- Arrange ---
        mock_client_instance = MockOpenAI.return_value
        mock_response = MagicMock()
        mock_response.choices[0].message.content = "Response based on history."
        mock_client_instance.chat.completions.create.return_value = mock_response

        history = [
            {"role": "user", "content": "Previous question"},
            {"role": "assistant", "content": "Previous answer"}
        ]
        
        # --- Act ---
        ask_deepseek("New question", history=history)

        # --- Assert ---
        # 验证 messages 列表是否正确包含历史记录
        call_args = mock_client_instance.chat.completions.create.call_args
        sent_messages = call_args[1]['messages']
        
        # 预期结构: [System, History(User), History(Assistant), User(New)]
        self.assertEqual(len(sent_messages), 4) # 1 System + 2 History + 1 New
        self.assertEqual(sent_messages[1]['content'], "Previous question")
        self.assertEqual(sent_messages[2]['content'], "Previous answer")
        self.assertEqual(sent_messages[3]['content'], "New question")

    @patch("src.Agent.deepseek_client.API_KEY", "") # 模拟 API Key 缺失
    def test_missing_api_key(self):
        """测试 API Key 缺失时的错误处理"""
        # 可以在 setUp 时保存原来的 KEY，这里临时清空环境变量
        original_key = os.environ.get("DEEPSEEK_API_KEY")
        if "DEEPSEEK_API_KEY" in os.environ:
            del os.environ["DEEPSEEK_API_KEY"]
            
        # 这里的 "mock_function" 不会真的被调用，因为函数开头就会 check Key
        # 注意: 因为我们在文件加载时已经读取了 API_KEY，所以需要reload 或者直接 patch 全局变量
        # 更好的做法是在函数内部读取 env，或者像下面这样 mock 模块级别的变量
        with patch("src.Agent.deepseek_client.API_KEY", ""):
             result = ask_deepseek("Hi")
             self.assertIn("Error: DEEPSEEK_API_KEY environment variable is not set", result)

        # 恢复 Key
        if original_key:
            os.environ["DEEPSEEK_API_KEY"] = original_key

if __name__ == '__main__':
    unittest.main()
