#!/bin/bash

export KMP_BLOCKTIME=1
export KMP_AFFINITY=granularity=fine,compact,1,0
export LD_PRELOAD=${LD_PRELOAD}:${CONDA_PREFIX}/lib/libiomp5.so
export LD_PRELOAD=${LD_PRELOAD}:${CONDA_PREFIX}/lib/libtcmalloc.so

export num_physical_cores=`lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l`
num_numa=$(numactl --hardware|grep available|awk -F' ' '{ print $2 }')

python ../../user_config.py
USER_CONF=user.conf

NUM_PROC=$num_numa
CPUS_PER_PROC=$((num_physical_cores/num_numa))
WORKERS_PER_PROC=2
TOTAL_SAMPLE_COUNT=50
BATCH_SIZE=4
TIMESTAMP=$(date +%m-%d-%H-%M)
HOSTNAME=$(hostname)
OUTPUT_DIR=offline-accuracy-output-${HOSTNAME}-batch-${BATCH_SIZE}-procs-${NUM_PROC}-ins-per-proc-${WORKERS_PER_PROC}-${TIMESTAMP}

DATASETPATH=./ILSVRC2012_img_val
# DATASETPATH="/data1/datasets/imgnet-train1k-val1k-dev/"

python runner.py --workload-name resnet50 \
	--scenario Offline \
	--mode Accuracy \
	--num-proc ${NUM_PROC} \
	--cpus-per-proc ${CPUS_PER_PROC} \
	--model-checkpoint-path ${CHECKPOINT_DIR} \
	--dataset-path ${DATASETPATH} \
	--batch-size ${BATCH_SIZE} \
	--mlperf-conf mlperf.conf \
	--user-conf user.conf \
	--precision int8 \
	--pad-inputs \
        --warmup \
	--quantized-model ./quantized_resnet50.pt \
	--workers-per-proc ${WORKERS_PER_PROC} \
	--total-sample-count ${TOTAL_SAMPLE_COUNT} \
	--output-dir ${OUTPUT_DIR} \
	2>&1 | tee ${OUTPUT_DIR}.log


if [ -e ${OUTPUT_DIR}/mlperf_log_accuracy.json ]; then
	echo " ==================================="
	echo "         Evaluating Accuracy        "
	echo " ==================================="

	python vision_tools/accuracy-imagenet.py --mlperf-accuracy-file ${OUTPUT_DIR}/mlperf_log_accuracy.json \
		--dataset-path ${DATASETPATH} --total-sample-count ${TOTAL_SAMPLE_COUNT} 2>&1 | tee -a ${OUTPUT_DIR}/accuracy-offline-${TIMESTAMP}.txt ${OUTPUT_DIR}.log
fi

# cp ./$OUTPUT_DIR/* .
# cp ${OUTPUT_DIR}/accuracy-offline-${TIMESTAMP}.txt accuracy.txt
