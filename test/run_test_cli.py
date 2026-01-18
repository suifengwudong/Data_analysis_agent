import os
import sys
import shutil
import json
from dotenv import load_dotenv, find_dotenv

# Add project root to path
# Determine paths relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

sys.path.append(PROJECT_ROOT)

# Load env vars
load_dotenv(find_dotenv(filename=os.path.join(PROJECT_ROOT, ".env")))

from main import create_agent

def run_test():
    working_directory = os.path.join(PROJECT_ROOT, "temp_files", "test_run_prompt_v2")
    if not os.path.exists(working_directory):
        os.makedirs(working_directory)
        
    print(f"Test working directory: {working_directory}")

    # Copy data file
    src_file_path = os.path.join(PROJECT_ROOT, "test", "Meteorite_Landings.csv")
    if not os.path.exists(src_file_path):
        print("Source data file not found at expected location. Searching...")
        # Fallback search or just error out since we know where it *should* be
        print(f"Error: Could not find {src_file_path}")
        return

    dst_file = os.path.join(working_directory, "Meteorite_Landings.csv")
    shutil.copy2(src_file_path, dst_file)
    print(f"Copied data to: {dst_file}")
    
    # Initialize the agent (headless mode -> use_gradio=False)
    agent, r_client = create_agent(working_directory=working_directory, use_gradio=False)
    
    # Read the prompt from the file
    prompt_path = os.path.join(SCRIPT_DIR, "prompt.md")
    try:
        with open(prompt_path, "r", encoding="utf-8") as f:
            full_prompt_text = f.read()
    except Exception as e:
        print(f"Error reading prompt file: {e}")
        r_client.close()
        return

    # 1. Extract Output Requirements (at the end)
    if "## 输出要求" in full_prompt_text:
        main_content, output_reqs = full_prompt_text.split("## 输出要求", 1)
        output_reqs = "## 输出要求" + output_reqs
    else:
        main_content = full_prompt_text
        output_reqs = ""

    # 2. Split by Modules
    # re.split includes the delimiter if captured, but using lookahead (?=...) keeps it in the following string
    import re
    parts = re.split(r'(?=### 模块)', main_content)
    
    preamble = parts[0]
    modules = parts[1:] if len(parts) > 1 else []

    print(f"\nFound {len(modules)} modules to execute.\n")
    
    data_context = f"\n\n数据文件路径: \"{dst_file.replace(os.sep, '/')}\"\n"

    # 3. Execute sequentially
    try:
        # Step 1: Preamble + Module 0
        if modules:
            # First turn: Preamble + Module 0 + Data Context + Output Reqs
            combined_prompt = preamble + "\n" + modules[0] + data_context + "\n" + output_reqs
            print(f"\n--- Executing Module 0 (and setup) ---\n")
            result = agent.analyze(combined_prompt)
            print(f"\n[Result Module 0]:\n{result}\n")
            
            # Subsequent turns
            for i, mod_text in enumerate(modules[1:], start=1):
                # For later modules, we just provide the specific instructions and output requirements
                step_prompt = mod_text + "\n" + output_reqs
                print(f"\n--- Executing Module {i} ---\n")
                result = agent.analyze(step_prompt)
                print(f"\n[Result Module {i}]:\n{result}\n")
        else:
            # Fallback if no modules found (just run everything)
            print("No modules detected, running full prompt.")
            final_prompt = full_prompt_text + data_context
            result = agent.analyze(final_prompt)
            print(result)
            
        print("\n--- All Analysis Complete ---\n")

    except Exception as e:
        print(f"\nAnalysis Failed: {e}")
    finally:
        r_client.close()

if __name__ == "__main__":
    run_test()
