#!/bin/bash
# setup_ollama.sh - Bash commands only
ollama run qwen3:8b-q4_K_M &
ollama run qwen3:30b-a3b-instruct-2507-q4_K_M &
ollama run qwen3:14b-q4_K_M
