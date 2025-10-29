#!/bin/bash
# setup_ollama_llama3.sh - Bash commands only
ollama pull llama3.2:3b-instruct-q4_K_M &
ollama pull llama3:8b-instruct-q8_0 &
ollama pull gpt-oss:20b
# ollama pull llama3.1:70b-instruct-q4_0
