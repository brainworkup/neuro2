#!/bin/bash
# setup_ollama_qwen3.sh - Bash commands only
ollama pull qwen3:4b-instruct-2507-q4_K_M &
ollama pull qwen3:8b-q8_0 &
ollama pull qwen3:30b-a3b-instruct-2507-q4_K_M
# ollama run qwen3:14b-q4_K_M


