#!/usr/bin/env python3
"""
WisperFlow - Quick API Key Tester
Tests Groq or OpenAI Whisper & Chat API connectivity using standard Python libraries.
No pip install or external packages needed.
"""

import sys
import os
import json
import urllib.request
import urllib.error

def test_api(provider: str, api_key: str):
    provider = provider.lower().strip()
    api_key = api_key.strip()

    if not api_key:
        print("❌ Error: API key cannot be empty.")
        return False

    if provider == "groq":
        url = "https://api.groq.com/openai/v1/chat/completions"
        model = "llama-3.1-8b-instant"
        display = "Groq"
    elif provider == "openai":
        url = "https://api.openai.com/v1/chat/completions"
        model = "gpt-4o-mini"
        display = "OpenAI"
    else:
        print(f"❌ Unknown provider '{provider}'. Choose 'groq' or 'openai'.")
        return False

    payload = {
        "model": model,
        "messages": [
            {"role": "user", "content": "Say hello in 5 words or less."}
        ],
        "max_tokens": 15
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        },
        method="POST"
    )

    print(f"📡 Testing connection to {display} ({model})...")
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                reply = data["choices"][0]["message"]["content"].strip()
                print(f"✅ Success! {display} connection is working perfectly.")
                print(f"   Model response: \"{reply}\"")
                return True
            else:
                print(f"❌ Server returned HTTP status {response.status}")
                return False
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        try:
            err_json = json.loads(error_body)
            msg = err_json.get("error", {}).get("message", error_body)
            print(f"❌ {display} API Error ({e.code}): {msg}")
        except Exception:
            print(f"❌ {display} API Error ({e.code}): {error_body}")
        return False
    except Exception as e:
        print(f"❌ Network or connection error: {e}")
        return False

def main():
    print("=" * 45)
    print(" 🎙️  WisperFlow API Key Tester")
    print("=" * 45)

    provider = sys.argv[1] if len(sys.argv) > 1 else None
    key = sys.argv[2] if len(sys.argv) > 2 else None

    if not provider:
        provider = input("Select provider [groq / openai] (default: groq): ").strip() or "groq"

    if not key:
        env_key = os.environ.get(f"{provider.upper()}_API_KEY", "")
        if env_key:
            use_env = input(f"Found {provider.upper()}_API_KEY in environment. Use it? [Y/n]: ").strip().lower()
            if use_env in ("", "y", "yes"):
                key = env_key

    if not key:
        key = input(f"Enter your {provider.capitalize()} API key: ").strip()

    test_api(provider, key)

if __name__ == "__main__":
    main()
