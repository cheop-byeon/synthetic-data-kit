# Synthetic Data Kit

This repository is derived from [meta-llama/synthetic_data_kit](https://github.com/meta-llama/synthetic-data-kit).
We keep the core source code and add minor adjustments such as target-file checks (skip if output exists) to avoid repeated generation when batch jobs are resumed or time out. We also include the configs used for our synthetic data generation runs. This repo is provided to reproduce our synthetic textual data; it is not an upstream contribution.

For full functionality (text, video, multimodal, task-specific reasoning, etc.), refer to the upstream repository. Below we document only the parts used for our runs.

## Generated Synthetic Data

This toolkit was used to generate **RFCAlign**, a synthetic dataset that aligns RFC (Request for Comments) design decisions with their supporting rationale from mailing-list discussions.

📦 **Dataset**: [jiebi/RFCAlign](https://huggingface.co/datasets/jiebi/RFCAlign)

The dataset contains raitonale-decision pairs, generated using the workflows described in this repository.

## CLI overview

Core commands:

- `ingest`: parse files (PDF, HTML, DOCX, emails, etc.)
- `create`: generate fine-tuning formats (`qa`, `cot`, `summary`)


## Installation

```bash
git clone https://github.com/cheop-byeon/synthetic-data-kit.git
cd synthetic-data-kit

conda create -p path/to/.conda/envs/synthetic-data python=3.10
conda activate path/to/.conda/envs/synthetic-data

pip install -e .
```

## Commands we used

### 1. Lookup
- Check usage

```bash
synthetic-data-kit --help
```

### 2. Tool setup
- Check if your backend is running

```bash
synthetic-data-kit system-check
```

- Create directory structure for data processing

```bash
mkdir -p data/{input,parsed,generated}
```

### 3. Usage

The basic flow is: `ingest` → `create`. Parsed data is stored in Lance format by default.

### 3.1 Batch directory processing

Process entire directories of files with a single command:

```bash
# Step 1: Parse all documents in a directory
synthetic-data-kit -c configs/custom_config.yaml ingest "./data/input/mailing-lists/ace" -o "./data/parsed/ace"
# Processes all .pdf, .html, .docx, .pptx, .txt, .msg.txt files
# Saves parsed files to data/parsed/ (as .lance files)

# Step 2: Generate QA pairs for all parsed files
synthetic-data-kit -c configs/custom_config.yaml create "./data/parsed/ace" --type qa -o "./data/generated/llama/ace"
# Processes all .lance files in the directory
# Saves QA pairs to data/generated/ (as .json files)
```

## Configuration

The toolkit uses YAML config files. Our configs are under [configs/](configs/):

- [configs/llama_config_vllm.yaml](configs/llama_config_vllm.yaml)
- [configs/llama_config_api.yaml](configs/llama_config_api.yaml)
- [configs/qwen_config_vllm.yaml](configs/qwen_config_vllm.yaml)

## Running scripts

We recommend using `huggingface-cli` to download the open-source models locally, for example:

```bash
huggingface-cli download meta-llama/Llama-3.3-70B-Instruct --local-dir ./meta-llama/Llama-3.3-70B-Instruct

sbatch running_llama_vllm.sh
# OR
sbatch running_llama_api.sh
# OR
sbatch running_qwen_vllm.sh

```
## Document processing and chunking

### How chunking works

The toolkit automatically handles documents of any size:

- **Small documents** (< 8000 characters): Processed in a single API call for maximum context and quality
- **Large documents** (≥ 8000 characters): Automatically split into chunks with overlap to maintain context

### Controlling chunking behavior

You can customize chunking with CLI flags or config settings for both single files and directories:

```bash
# Single file with custom chunking
synthetic-data-kit create document.txt --type qa --chunk-size 2000 --chunk-overlap 100

# Directory processing with custom chunking
synthetic-data-kit create ./data/parsed/ --type cot --num-pairs 50 --chunk-size 6000 --verbose
```

### Chunking parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--chunk-size` | 4000 | Size of text chunks in characters |
| `--chunk-overlap` | 200 | Overlap between chunks to preserve context |
| `--verbose` | false | Show chunking details and progress |

### Understanding chunking output

When using `--verbose`, you'll see chunking information for both single files and directories:

```bash
# Directory verbose output
synthetic-data-kit create ./data/parsed/ --type qa --num-pairs 20 --verbose
```

### Chunking logic

Both QA and CoT generation use the same chunking logic for files and directories:

```bash
# Directory processing
synthetic-data-kit create ./data/parsed/ --type qa --num-pairs 100 --chunk-size 3000
```


## Troubleshooting FAQs

### vLLM server issues

- Ensure vLLM is installed: `pip install vllm`
- Start server with: `vllm serve <model_name> --port 8000`
- Check connection: `synthetic-data-kit system-check`

### Memory issues

If you encounter CUDA out of memory errors:
- Use a smaller model
- Reduce batch size in config
- Start vLLM with `--gpu-memory-utilization 0.85`

### JSON parsing issues

If you encounter issues with the `curate` command:
- Use the `-v` flag to enable verbose output
- Set smaller batch sizes in your config.yaml
- Ensure the LLM model supports proper JSON output
- Install json5 for enhanced JSON parsing: `pip install json5`

## License

Read the [License](LICENSE).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md).


## Acknowledgements

Thanks to the contributors of [meta-llama/synthetic_data_kit](https://github.com/meta-llama/synthetic-data-kit).