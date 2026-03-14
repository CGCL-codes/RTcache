#!/bin/bash
#
# gem5-graph.sh - RTcache gem5 + SPEC/graph500 批量模拟脚本
#
# 功能: 遍历 cache-type、wl-type、hbm-size 等参数组合，
#       在 graph500 基准测试上运行 gem5 模拟
#       包含 fast-forward（跳过前N条指令预热）和 L2 cache 配置
#
# 用法: ./gem5-graph.sh <output_directory>

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <output_directory>"
  exit 1
fi

output_base_dir=$1

# ===== 路径配置 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
gem5_dir="$(cd "$SCRIPT_DIR/.." && pwd)"
gem5_script="$gem5_dir/configs/deprecated/example/diy.py"
graph500_dir="/home/chen/graph500-2.1.4/seq-csr"

# ===== 参数配置 =====
cache_types=(0 1 2 3)
wl_types=(0 1 2 3)
pre_values=(0 1)
dt_values=(0)
rt_group_values=(8)
fast_forward_values=(200000000)
max_inst_values=(1000000000)
hbm_sizes=(4kB 16kB 32kB)

graph500_command='-c '"$graph500_dir"'/seq-csr --option="-s 18 -e 16"'

max_jobs=80

if [ ! -f "$gem5_dir/build/X86/gem5.opt" ]; then
  echo "Error: gem5 binary not found at $gem5_dir/build/X86/gem5.opt"
  exit 1
fi

is_memory_sufficient() {
  local free_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local free_memory_percentage=$((free_memory_kb * 100 / total_memory_kb))
  [ "$free_memory_percentage" -gt 50 ]
}

process_graph500_test() {
  local cache_type=$1 wl_type=$2 swap_time=$3 pre=$4
  local dt=$5 rt_group=$6 fast_forward=$7 max_inst=$8 hbm_size=$9

  local output_dir="$output_base_dir/graph500_cache${cache_type}_wl${wl_type}_swap${swap_time}_pre${pre}_ff${fast_forward}_I${max_inst}_hbm${hbm_size}"
  [ "$cache_type" -eq 1 ] && output_dir+="_dt${dt}_rtgroup${rt_group}"
  mkdir -p "$output_dir"

  cd "$graph500_dir"

  local cmd="$gem5_dir/build/X86/gem5.opt --outdir=$output_dir -re $gem5_script"
  cmd+=" $graph500_command --cpu-type X86TimingSimpleCPU --cpu-clock 3GHz"
  cmd+=" --cache-type=$cache_type --wl-type=$wl_type --swap-time=$swap_time"
  cmd+=" --hbm-size=$hbm_size --pre=$pre --fast-forward=$fast_forward"
  cmd+=" --hybird=true --l2cache --l1d_size 16kB --l1i_size 64kB --l2_size 256kB"
  [ "$cache_type" -eq 1 ] && cmd+=" --rt-dt=$dt --rt-group=$rt_group"

  echo "Executing: $cmd"
  eval $cmd
}

# ===== 主循环 =====
for wl_type in "${wl_types[@]}"; do
  [ "$wl_type" -eq 3 ] && cache_types=(0)

  for cache_type in "${cache_types[@]}"; do
    case $wl_type in
      0|3) swap_times=(2048) ;;
      1)   swap_times=(32) ;;
      2)   swap_times=(10) ;;
    esac

    for swap_time in "${swap_times[@]}"; do
      for pre in "${pre_values[@]}"; do
        for fast_forward in "${fast_forward_values[@]}"; do
          for max_inst in "${max_inst_values[@]}"; do
            for hbm_size in "${hbm_sizes[@]}"; do
              if [ "$cache_type" -eq 1 ]; then
                for dt in "${dt_values[@]}"; do
                  for rt_group in "${rt_group_values[@]}"; do
                    while [ $(jobs | wc -l) -ge $max_jobs ] || ! is_memory_sufficient; do
                      sleep 10
                    done
                    process_graph500_test "$cache_type" "$wl_type" "$swap_time" "$pre" "$dt" "$rt_group" "$fast_forward" "$max_inst" "$hbm_size" &
                  done
                done
              else
                while [ $(jobs | wc -l) -ge $max_jobs ] || ! is_memory_sufficient; do
                  sleep 10
                done
                process_graph500_test "$cache_type" "$wl_type" "$swap_time" "$pre" 0 0 "$fast_forward" "$max_inst" "$hbm_size" &
              fi
            done
          done
        done
      done
    done
  done
done

wait
echo "All tasks completed."
