# source("R/llm_summary_openai.R")

# Set paths for this test (use your real repo paths)
prompt_json <- "prompt/Prompt General Cognitive Ability.json"
iq_qmd <- "_02-01_iq_text.qmd"

Sys.setenv(LLM_MODEL = "gpt-5-mini-2025-08-07")
Sys.setenv(OPENAI_BASE_URL = "https://api.openai.com/v1")

generated <- generate_iq_summary_openai(
  prompt_json_path = prompt_json,
  qmd_path = iq_qmd,
  model = "gpt-5-mini-2025-08-07",
  temperature = 1,
  echo_mode = "none"
)

cat("\n--- Generated Summary ---\n", generated, "\n")


# LLM Batch ---------------------------------------------------------------

source("R/llm_batch_openai.R")

master_json <- "prompt/neuro2_prompts.json" # master prompts
base_dir <- "." # where your *_text.qmd live

res_iq <- generate_domain_summary_from_master(
  master_json = master_json,
  domain_keyword = "priq",
  model = Sys.getenv("LLM_MODEL", unset = "gpt-5-mini-2025-08-07"),
  temperature = 1,
  base_dir = base_dir,
  echo = "none"
)

cat("\n--- GENERATED IQ SUMMARY ---\n", res_iq$text, "\n")

## sirf

res_iq <- generate_domain_summary_from_master(
  master_json = master_json,
  domain_keyword = "pr.sirf",
  model = Sys.getenv("LLM_MODEL", unset = "gpt-5-mini-2025-08-07"),
  temperature = 1,
  base_dir = base_dir,
  echo = "none"
)

cat("\n--- GENERATED SIRF SUMMARY ---\n", res_iq$text, "\n")


# or batch across major cognitive domains:
all_out <- run_llm_for_all_domains(
  master_json = master_json,
  base_dir = base_dir
)

# Then your LLM wrapper function becomes:
generate_domain_summary_from_master(
  master_json = system.file(
    "prompts",
    "neuro2_prompts.json",
    package = "neuro2"
  ),
  domain_keyword = "pracad",
  model = "gpt-4.1-mini"
)


# Then your LLM wrapper function becomes:
generate_domain_summary_from_master(
  master_json = system.file(
    "prompts",
    "neuro2_prompts.json",
    package = "neuro2"
  ),
  domain_keyword = "prsirf",
  model = "gpt-4.1-mini"
)

json_path <- system.file("prompts", "neuro2_prompts.json", package = "neuro2")


res_sirf <- generate_domain_summary_from_master(
  master_json = system.file(
    "prompts",
    "neuro2_prompts.json",
    package = "neuro2"
  ),
  domain_keyword = "prsirf", # now matches pr.sirf
  model = "gpt-4.1-mini",
  temperature = 0.2,
  base_dir = your_qmd_root, # e.g., "." or the path where *_text.qmd live
  echo = "none"
)


res_sirf <- neuro2::generate_domain_summary_from_master(
  master_json = system.file(
    "prompts",
    "neuro2_prompts.json",
    package = "neuro2"
  ),
  domain_keyword = "prsirf", # also works with "pr.sirf"
  model = "gpt-4.1-mini",
  base_dir = "." # wherever your *_text.qmd live
)
