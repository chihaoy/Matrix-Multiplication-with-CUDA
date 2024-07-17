#!/bin/bash

# 定义数组
sizes=(256 257 512 1024 2048 4096 4097)

# 确保结果目录存在
mkdir -p ./results/blk_16_16_t_4_4_1

# 遍历数组
for size in "${sizes[@]}"; do
    # 构建输出文件名
    output_file="./results/blk_16_16_t_4_4_1/n_${size}.log"

    # 执行命令并重定向输出到文件
    echo "Running ./mmpy with size ${size}"
    ./run_T4.sh mode=tiling bx=16 by=16 tm=4 tn=4 tk=1 n=${size} > "${output_file}"

    # 可选：回显日志文件的生成状态
    echo "Output saved to ${output_file}"
done

echo "All tasks completed."
