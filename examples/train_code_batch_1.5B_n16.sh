#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

EXP_NAME=ppo-zero-distill-1.5B-n16-jun1
MODEL_NAME="DeepSeek-R1-Distill-Qwen-1.5B"
DATASET_NAME="codeparrot-apps-test.jsonl"
NODES=16
ALLOCATION_MODE="vllm.d64p1m1+d32p2m1"

LOG_DIR="/storage/ray/train_batch_logs/${EXP_NAME}/$(date +'%Y%m%d-%H%M%S')"
mkdir -p ${LOG_DIR}
echo "Log Dir: ${LOG_DIR}"

MAX_WORKERS=$(expr 16 / ${NODES})

FIFO_NAME=$(mktemp -u)
mkfifo "$FIFO_NAME"
exec 3<>"$FIFO_NAME"
rm -f "$FIFO_NAME"

for ((i=0; i<MAX_WORKERS; i++)); do
    echo >&3
done


ALL_PARAMS=(
    "${EXP_NAME} ${MODEL_NAME} ${DATASET_NAME} 1024 8 ${NODES} ${ALLOCATION_MODE} 16384 128 1 0.001"
    #"${EXP_NAME} ${MODEL_NAME} ${DATASET_NAME} 1024 8 ${NODES} ${ALLOCATION_MODE} 16384 128 1 0.001"
    #"${EXP_NAME} ${MODEL_NAME} ${DATASET_NAME} 1024 8 ${NODES} ${ALLOCATION_MODE} 16384 128 1 0.001"
)

echo "Task Count: ${#ALL_PARAMS[@]}"

for ((i=0; i<${#ALL_PARAMS[@]}; i++)); do
    read -u3

    {
        echo "$(date +"%Y-%m-%d %H:%M.%S") Task $i started: ${ALL_PARAMS[$i]}"
        bash -c "bash ${SCRIPT_DIR}/train_code_small_on_ray.sh ${ALL_PARAMS[$i]} &> ${LOG_DIR}/${i}.log"
        echo "$(date +"%Y-%m-%d %H:%M.%S") Task $i completed with exit code: $?, ${ALL_PARAMS[$i]}"
        sleep 120
        echo >&3
    } &

    sleep 120
done

wait

exec 3>&-
echo "All tasks completed"
