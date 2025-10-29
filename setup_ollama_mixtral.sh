#!/bin/bash
# setup_ollama.sh - Bash commands only
ollama pull mistral:7b-instruct-v0.3-q4_K_M
ollama pull mixtral:8x7b-instruct-q4_K_M
ollama pull mixtral:8x22b-instruct-q4_0

ollama pull llama3.2:3b-instruct-q4_K_M

# SIRF sections (14B) - Pick 1-2
ollama pull llama3:8b-instruct-q8_0
ollama pull command-r:35b-v0.1-q4_K_M

# Mega/comprehensive analysis (30B+) - Pick 1
ollama pull gpt-oss:20b
ollama pull llama3.1:70b-instruct-q4_0
ollama pull command-r:35b-v0.1-q4_K_M
