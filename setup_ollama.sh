#!/bin/bash
# setup_ollama.sh - Bash commands only
ollama pull gemma3:4b-it-qat
ollama pull gemma3:12b-it-qat
ollama pull gemma3:27b-it-qat

ollama pull qwen3:4b-instruct-2507-q4_K_M &
ollama pull qwen3:8b-q8_0 &
ollama pull qwen3:30b-a3b-instruct-2507-q4_K_M

# ollama run qwen3:14b-q4_K_M



ollama pull llama3.2:3b-instruct-q4_K_M
ollama pull mistral:7b-instruct-v0.3-q4_K_M

# SIRF sections (14B) - Pick 1-2
ollama pull llama3:8b-instruct-q8_0
ollama pull mixtral:8x7b-instruct-q4_K_M
ollama pull command-r:35b-v0.1-q4_K_M

# Mega/comprehensive analysis (30B+) - Pick 1
ollama pull gpt-oss:20b
ollama pull llama3.1:70b-instruct-q4_0
ollama pull command-r:35b-v0.1-q4_K_M
ollama pull mixtral:8x22b-instruct-q4_0
