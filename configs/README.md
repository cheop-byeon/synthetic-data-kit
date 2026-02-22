# Synthetic Data Kit Configuration Files

This directory contains configuration files for the Synthetic Data Kit. Each configuration file is tailored for different deployment scenarios and use cases.

## Overview

The Synthetic Data Kit uses YAML configuration files to control all aspects of data processing, from LLM provider selection to prompt customization. Choose the configuration that best matches your deployment scenario.

## Available Configurations

### 1. `llama_config_api.yaml` - Cloud API Provider Configuration

**Use this when:**
- You don't have local GPU resources (e.g., A100, H100)
- Hardware requirements cannot be met locally
- Working with non-sensitive data (no information leakage concerns)
- Need quick setup without managing infrastructure
- Using commercial API providers

**Supported providers:**
- OpenAI API
- OpenRouter
- Llama API (https://api.llama.com)
- Any OpenAI-compatible API endpoint

**Key settings:**
```yaml
llm:
  provider: "api-endpoint"

api-endpoint:
  api_base: "https://openrouter.ai/api/v1"  # or your API endpoint
  api_key: "your-api-key"
  model: "meta-llama/llama-3.3-70b-instruct"
  sleep_time: 0.5  # Rate limiting delay
```

**Advantages:**
- No GPU required
- Pay-per-use pricing
- Instant scalability
- No infrastructure management

**Considerations:**
- Data privacy (sent to third-party)
- API costs
- Rate limits
- Network dependency

---

### 2. `llama_config_vllm.yaml` - Local vLLM Server Configuration

**Use this when:**
- You have local GPU access (A100, H100, or similar)
- Working with sensitive/proprietary data
- Need full control over infrastructure
- Want to avoid API costs for large-scale processing
- Require offline/air-gapped deployment

**Requirements:**
- GPU with sufficient VRAM (typically 40GB+ for 70B models)
- vLLM server running locally
- Downloaded open-source model weights

**Key settings:**
```yaml
llm:
  provider: "vllm"

vllm:
  api_base: "http://localhost:8888/v1"
  port: 8888
  model: "meta-llama/Llama-3.3-70B-Instruct"
  sleep_time: 0.1  # Lower delay for local inference
```

**Advantages:**
- Complete data privacy
- No per-request costs
- Full control over model and parameters
- Lower latency (no network overhead)
- Unlimited requests

**Setup required:**
1. Download model weights
2. Start vLLM server:
   ```bash
   vllm serve meta-llama/Llama-3.3-70B-Instruct \
     --port 8888 \
     --dtype auto \
     --max-model-len 4096
   ```
3. Point configuration to `http://localhost:8888/v1`

---

### 3. `config.yaml` - Default Configuration

The base configuration file used by default if no custom config is specified. Uses local vLLM setup with Qwen models.

---

### 4. `qwen_config1.yaml` - Qwen Model Configuration

Optimized for Qwen/Qwen2.5 model family with adjusted parameters.

---

## Core Configuration Sections

### Paths Configuration
Controls input/output directories for the 4-stage pipeline:
```yaml
paths:
  input: "data/input"              # Source documents (PDF, HTML, TXT, etc.)
  output:
    parsed: "data/parsed"          # Stage 1: Ingested text
    generated: "data/generated"    # Stage 2: Generated QA pairs
    curated: "data/curated"        # Stage 3: Quality-filtered pairs
    final: "data/final"            # Stage 4: Final training formats
```

### LLM Generation Parameters
Fine-tune generation behavior:
```yaml
generation:
  temperature: 0.7      # 0.1-1.0: Lower = more deterministic
  top_p: 0.95          # Nucleus sampling
  chunk_size: 4000     # Text chunk size for processing
  overlap: 200         # Context overlap between chunks
  max_tokens: 4096     # Max response length
  num_pairs: 25        # QA pairs per document
  batch_size: 32       # Parallel processing batch size
```

### Content Curation Parameters
Control quality filtering:
```yaml
curate:
  threshold: 7.0       # Quality score threshold (1-10 scale)
  batch_size: 5        # Items per rating batch
  temperature: 0.1     # Lower = more consistent ratings
```

## The `qa_generation` Prompt

The `qa_generation` prompt is the core of the synthetic data generation process. It's defined in the `prompts` section and controls how QA pairs are extracted from documents.

**Location in config:**
```yaml
prompts:
  qa_generation: |
    Your task is to analyze the provided IETF email...
    [prompt content]
```

**Usage in code:**
The prompt is accessed in [synthetic_data_kit/generators/qa_generator.py](../synthetic_data_kit/generators/qa_generator.py) via:
```python
qa_prompt_template = get_prompt(self.config, "qa_generation")
```

**Current implementation:**
The `qa_generation` prompt in this configuration:
1. **Classifies emails** for relevance to technical discussions
2. **Filters out** social communications and automated notifications
3. **Extracts or synthesizes snippets** that reflect RFC/I-D content
4. **Returns structured JSON** with relevance assessment and snippet

**Important: Field Mapping for IETF Email Workflow**

While the toolkit uses standard "question/answer" terminology, in this IETF email processing workflow:
- **"question" field** → Corresponds to **Rationale** (email commentary, discussion)
- **"answer" field** → Corresponds to **Decision** (RFC/I-D snippet, technical specification)

This mapping allows you to leverage the standard QA generation framework for your specialized Rationale→Decision extraction task.

**Customization:**
You can modify this prompt to:
- Change the domain (legal, medical, etc.)
- Adjust output format
- Alter quality criteria
- Include/exclude specific types of content

## Quick Start Examples

### Using API configuration:
```bash
sdk create \
  --config configs/llama_config_api.yaml \
  --input data/input \
  --output data/generated
```

### Using local vLLM:
```bash
# 1. Start vLLM server first
vllm serve meta-llama/Llama-3.3-70B-Instruct --port 8888

# 2. Run processing
sdk create \
  --config configs/llama_config_vllm.yaml \
  --input data/input \
  --output data/generated
```

### Override specific parameters:
```bash
sdk create \
  --config configs/llama_config_api.yaml \
  --num-pairs 50 \
  --temperature 0.8
```

## Configuration Priority

Command-line arguments override config file values:
1. CLI arguments (highest priority)
2. Custom config file (if specified)
3. Default `config.yaml` (if no config specified)
4. Built-in defaults (lowest priority)

## Best Practices

1. **Keep API keys secure**: Use environment variables instead of hardcoding
   ```yaml
   api-endpoint:
     api_key: "${OPENROUTER_API_KEY}"
   ```

2. **Adjust batch sizes**: 
   - Larger for local vLLM (32+)
   - Smaller for API endpoints (5-10) to avoid rate limits

3. **Temperature settings**:
   - Generation: 0.7 (balanced creativity)
   - Rating: 0.1 (consistent evaluations)

4. **Chunk size optimization**:
   - Larger chunks = better context
   - Smaller chunks = more granular QA pairs
   - Balance based on document complexity

5. **Quality threshold**:
   - Higher (8-10): Only best quality, lower volume
   - Lower (6-7): More permissive, higher volume

## Troubleshooting

**API rate limits:**
- Increase `sleep_time` in api-endpoint config
- Reduce `batch_size` in generation config

**vLLM connection errors:**
- Verify server is running: `curl http://localhost:8888/v1/models`
- Check port matches configuration
- Ensure model loaded successfully

**Low quality outputs:**
- Increase `curate.threshold`
- Adjust `qa_generation` prompt for better instructions
- Lower `generation.temperature` for more focused outputs

## Detailed Workflow: From Prompt to JSON Output

This section explains the complete processing pipeline when using the `qa_generation` prompt to generate synthetic data.

### Step-by-Step Processing Flow

#### 1. **Configuration Loading**
- **File**: Based on your configuration (earlier search results indicated this happens in the toolkit's core modules)
- **Function**: Configuration is loaded via YAML parser
- **What happens**: 
  - The system reads your chosen config file (e.g., `llama_config_api.yaml`)
  - Extracts all settings including `prompts.qa_generation`
  - Sets up LLM provider (vLLM or API endpoint)
  - Configures paths, generation parameters, and quality thresholds

#### 2. **Document Ingestion**
- **Input**: Raw documents (e.g., `wg_email_no.msg.txt`, email files)
- **Input location**: `data/input/` or specified directory
- **Formats supported**: PDF, HTML, DOCX, PPT, TXT, YouTube transcripts, email (.msg.txt)
- **Output location**: `data/parsed/`
- **Output format**: Lance format (`.lance` files)
- **What happens**:
  - Documents are parsed into clean text
  - Metadata is extracted (source, title, etc.)
  - Data is stored in Lance columnar format: `wg_email_no.msg.lance`
  - Lance format enables efficient querying and processing

#### 3. **Text Chunking & Preparation**
- **Function**: `split_into_chunks()` 
- **Parameters from config**:
  - `generation.chunk_size`: 4000 (default)
  - `generation.overlap`: 200 (context preservation)
- **What happens**:
  - Large documents are split into manageable chunks
  - Overlap ensures context isn't lost at chunk boundaries
  - Each chunk is prepared for individual processing

#### 4. **QA Generation via LLM**
- **Core File**: `synthetic_data_kit/generators/qa_generator.py`
- **Key Function**: `generate_qa_pairs()`
- **Prompt Access**: 
  ```python
  # Line ~114 in qa_generator.py
  qa_prompt_template = get_prompt(self.config, "qa_generation")
  ```

**Detailed substeps**:

a. **Prompt Formatting**:
   - The `qa_generation` prompt template is retrieved
   - Variables are replaced:
     - `{text}`: Current document chunk
     - `{num_pairs}`: Number of QA pairs to generate
     - `{summary}`: Document summary (first 100 chars)
   
b. **LLM API Call**:
   - Formatted prompt is sent to LLM (vLLM or API endpoint)
   - Batch processing used for efficiency (`generation.batch_size`)
   - Retries configured via `max_retries` and `retry_delay`
   - Rate limiting via `sleep_time` parameter

c. **Response Parsing**:
   - **Function**: `parse_qa_pairs()` (from `utils.llm_processing`)
   - **Expected format**: JSON array with objects containing specific fields
   - For your IETF email use case:
     ```json
     [
       {
         "relevance": "Yes or No",
         "snippet": "quoted or synthesized RFC/I-D text"
       }
     ]
     ```
   - Handles malformed JSON gracefully
   - Extracts valid pairs, discards errors

d. **Data Accumulation**:
   - All QA pairs from all chunks are collected
   - Stored in memory for output

#### 5. **Format Conversion & Output**
- **Output location**: 
  - Generated: `data/generated/` → `wg_email_no.msg_qa_pairs.json`

**JSON Output Structure** (Standard Workflow):

After `create` command (`data/generated/wg_email_no.msg_qa_pairs.json`):

```json
{
  "summary": "Brief document summary",
  "qa_pairs": [
    {
      "question": "Email commentary/rationale text",
      "answer": "RFC/I-D decision/specification snippet"
    },
    {
      "question": "Another rationale...",
      "answer": "Corresponding decision..."
    }
  ]
}
```

**Note**: In this IETF workflow, `question` = **Rationale** (email discussion), `answer` = **Decision** (RFC snippet)

**Field Descriptions**:
- `summary`: Document summary (may be empty)
- `qa_pairs`: Array of question-answer pairs
  - `question`: **Rationale** - Email text or commentary from IETF discussions
  - `answer`: **Decision** - RFC/I-D snippet or synthesized technical specification
  - *Note: The QA format is repurposed for Rationale→Decision mapping*

#### 6. **Optional: Custom Post-Processing**
Your custom scripts (`process.rfc.*.py`) can perform additional transformations:
- **Purpose**: Convert generated data to specialized formats
- **Example**: `process.rfc.8374.c2i.py` - Commentary-to-I-D format
- **Output**: JSONL files with query-passage structure for retrieval training
- **Note**: This is optional and project-specific (for IETF RFC work)

### Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Load Config (llama_config_api.yaml)                      │
│    ├─ LLM Provider Settings                                 │
│    ├─ Generation Parameters                                 │
│    └─ Prompts (including qa_generation)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────                                         │
│    Input:  data/input/wg_email_no.msg.txt                        │
│    Output: data/parsed/wg_email_no.msg.lance (Lance format)     │
│    → Parse to text (data/parsed/)                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Chunk Text                                               │
│    ├─ chunk_size: 4000 chars                                │
│    └─ overlap: 200 chars                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Generate QA Pairs                                        │
│    ├─ Format qa_generation prompt with {text}              │
│    ├─ Call LLM API (batch processing)                       │
│    ├─ Parse JSON response                                   │
│    └─ Extract relevance + snippet pairs                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Output JSON Files                                        │
│    Output: data/generated/wg_email_no.msg_qa_pairs.json    │
│                                                              │
│    Structure:                                                │
│    {                                                         │
│      "summary": "",                                          │
│      "qa_pairs": [{                                          │
│        "question": "Rationale (email content)",             │
│        "answer": "Decision (RFC/I-D snippet)"                │
│      }]                                                      │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Custom Post-Processing (Optional, Project-Specific)      │
│    ├─ process.rfc.8374.c2i.py (commentary→I-D)             │
│    └─ Create specialized retrieval training data            │
└─────────────────────────────────────────────────────────────┘
```

### Key Functions ReferenEmail Document

```bash
# Batch process workflow
synthetic-data-kit ingest data/input/          # Step 1: Parse emails
synthetic-data-kit create data/parsed/ --type qa  # Step 2-5: Generate R/D pairs
```

**File transformations**:

1. **Input**: `wg_email_no.msg.txt` in `data/input/`
   - Raw email content from IETF mailing list

2. **After ingest**: `wg_email_no.msg.lance` in `data/parsed/`
   - Parsed and stored in Lance columnar format

3. **Chunking**: Text split into chunks (if >4000 chars with 200 overlap)
   - Example: 1 email might become 1-3 chunks depending on length

4. **LLM Processing** (create command):
   - Process each chunk through `qa_generation` prompt
   - Extract email content and RFC/I-D snippets
   - Generate relevance assessments

5. **Generated output**: `wg_email_no.msg_qa_pairs.json` in `data/generated/`
   ```json
   {
     "summary": "",
     "qa_pairs": [
       {"question": "Rationale (email text)...", "answer": "Decision (RFC snippet)..."},
       {"question": "Rationale (email text)...", "answer": "Decision (RFC snippet)..."}
     ]
   }
   ```

6. **Optional post-processing**: Custom scripts can transform data for specific use cases

### Example: Tracing One Document

1. **Input**: `IETF_email_thread.txt` in `data/input/`
2. **After parsing**: `IETF_email_thread.txt` in `data/parsed/`
3. **Chunking**: Split into 3 chunks (if >4000 chars with 200 overlap)
4. **LLM Processing**:
   - Chunk 1 → 5 email-snippet pairs
   - Chunk 2 → 5 email-snippet pairs
   - Chunk 3 → 3 email-snippet pairs
   - Total: 13 pairs generated
5. **Quality filtering**:
   - 13 pairs rated → 9 pairs score ≥7.0 → 9 retained
6. **Output**: `IETF_email_thread.jsonl` with 9 entries in `data/curated/`

### Performance Considerations

- **Batch size**: Larger = faster but more memory
- **Chunk size**: Smaller = more granular but more API calls
- **Sleep time**: Balance between speed and rate limits
- **Threshold**: Higher = better quality but fewer examples

## Additional Resources

- [Main Documentation](../DOCS.md)
- [Getting Started Guide](../use-cases/getting-started/README.md)
- [Prompt Customization Examples](../DOCS.md#customizing-prompts)