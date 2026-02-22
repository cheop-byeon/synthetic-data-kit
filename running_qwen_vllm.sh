#!/bin/bash
#SBATCH --job-name=llama
#SBATCH --account=12345677
#SBATCH --time=00-05:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=48G
#SBATCH --partition=accel
#SBATCH --gpus=a100_80:1

module load Miniconda3/22.11.1-1
export PS1=\$
source ${EBROOTMINICONDA3}/etc/profile.d/conda.sh
conda deactivate &>/dev/null
echo "Conda environments: $(conda info --envs)"
echo "EBROOTMINCONDA3: ${EBROOTMINICONDA3}"
module load CUDA/12.6.0
conda activate path/to/.conda/envs/synthetic-data

export NCCL_P2P_DISABLE=1
export OMP_NUM_THREADS=2
unset http_proxy
unset https_proxy

vllm serve ./Qwen/Qwen2.5-32B-Instruct --port 8123 &

# Wait for the backend to start
sleep 600
echo "query starting..."

while true; do
    status=$(synthetic-data-kit -c ./configs/llama_config1.yaml system-check)
    echo ========================================================================
    echo "command return value: $?"
    echo $status | grep -q "Available models"
    echo "condition return value: $?"
    echo $status
    echo ========================================================================
    if echo $status | grep -q "Available models";then
        echo "Backend service is running."
        break
    else
        echo "Waiting for the backend to start..."
        sleep 10
    fi
done



MAX_JOBS=5

folders=(
    "quic" "acme" "privacy-pass" "cose" "core" "rtcweb" "httpapi" "suit" "tls" "rats"
    "webpush" "sacm" "webtransport" "oauth" "anima" "detnet" "sedate" "masque" "ietf-and-github" "opsawg"
    "jsonpath" "lake" "ppm" "pearg" "perc" "sframe" "t2trg" "taps" "wpack" "ccamp"
    "nwcrg" "emu" "txauth" "ohai" "netconf" "spasm" "dmarc" "dnsop" "dnssd" "doh"
    "mops" "moq" "multipathtcp" "captive-portals" "roll" "homenet" "mls" "iot-onboarding" "ice" "wish"
    "dhcwg" "scitt" "wimse" "ccwg" "snac" "avt" "tm-rid" "nmop" "cellar" "alto"
    "ietf-http-wg" "ace" "add"
)

function wait_for_jobs {
    while (( $(jobs -r | wc -l) >= MAX_JOBS + 1 )); do
        sleep 60
    done
}

for folder in "${folders[@]}"; do
    wait_for_jobs
    (
        echo "$(date +%H:%M:%S) - Starting $folder"
        synthetic-data-kit -c ./configs/qwen_config_vllm.yaml create "./data/parsed/$folder" --type qa -o "./data/generated/qwen/$folder"
        echo "$(date +%H:%M:%S) - Finished $folder"
    ) &
done

wait
