#!/bin/bash
#
# gem5-test.sh - RTcache gem5 模拟批量测试脚本
#
# 功能: 使用 gem5-modify-11.1 批量运行 SPEC CPU 基准测试，
#       遍历不同的 cache-type、wl-type、hbm-size、RT 等参数组合
#
# 用法: ./gem5-test.sh <output_directory>
#
# 依赖:
#   - gem5-modify-11.1 已编译 (build/X86/gem5.opt)
#   - SPEC CPU 2017 或 2006 基准测试已安装并编译
#
# 参数说明:
#   cache-type: 0=基线, 1=RT(Region Table), 2=HBM, 3=RT+HBM
#   wl-type: 写入策略 (0=WriteBack, 1=WriteThrough-32, 2=WriteThrough-10, 3=NoCache)
#   pre: 预取开关 (0=关闭, 1=开启)
#   RT: 是否启用 Region Table (0=关闭, 1=开启)

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

# SPEC CPU 配置 (二选一, 取消注释对应版本)
# --- SPEC CPU 2017 ---
spec_version="2017"
spec_base_dir="/home/chen/speccpu2017/benchspec/CPU"
spec_run_suffix="run/run_base_refrate_mytest-m64.0000"
# --- SPEC CPU 2006 (如果可用，取消下面注释并注释上面) ---
# spec_version="2006"
# spec_base_dir="/home/chen/spec2006"
# spec_run_suffix=""

# graph500 路径
graph500_dir="/home/chen/graph500-2.1.4/seq-csr"

# ===== 参数配置 =====
yu_wl_types=(1 2 3)
yu_cache_types=(0 1 2 3)
yu_pre_values=(0 1)
dt_values=(0)
rt_group_values=(8)
max_inst_values=(100000000)
hbm_sizes=(4kB)
rt_values=(0 1)

# ===== SPEC 测试命令定义 =====
declare -A spec_commands
declare -A spec_dirs

if [ "$spec_version" = "2017" ]; then
  # SPEC CPU 2017 (rate 版本, 全部已编译)
  spec_dirs[mcf]="505.mcf_r"
  spec_commands[mcf]='-c ./mcf_r_base.mytest-m64 --option="inp.in"'

  spec_dirs[lbm]="519.lbm_r"
  spec_commands[lbm]='-c ./lbm_r_base.mytest-m64 --option="3000 reference.dat 0 0 100_100_130_ldc.of"'

  spec_dirs[perlbench]="500.perlbench_r"
  spec_commands[perlbench]='-c ./perlbench_r_base.mytest-m64 --option="-I./lib splitmail.pl 6400 12 26 16 100 0"'

  spec_dirs[namd]="508.namd_r"
  spec_commands[namd]='-c ./namd_r_base.mytest-m64 --option="--input apoa1.input --output apoa1.ref.output --iterations 65"'

  spec_dirs[cactuBSSN]="507.cactuBSSN_r"
  spec_commands[cactuBSSN]='-c ./cactusBSSN_r_base.mytest-m64 --option="spec_ref.par"'

  spec_dirs[parest]="510.parest_r"
  spec_commands[parest]='-c ./parest_r_base.mytest-m64 --option="ref.prm"'

  spec_dirs[povray]="511.povray_r"
  spec_commands[povray]='-c ./povray_r_base.mytest-m64 --option="SPEC-benchmark-ref.ini"'

  spec_dirs[omnetpp]="520.omnetpp_r"
  spec_commands[omnetpp]='-c ./omnetpp_r_base.mytest-m64 --option="-c General -r 0"'

  spec_dirs[deepsjeng]="531.deepsjeng_r"
  spec_commands[deepsjeng]='-c ./deepsjeng_r_base.mytest-m64 --option="ref.txt"'

  spec_dirs[xalancbmk]="523.xalancbmk_r"
  spec_commands[xalancbmk]='-c ./cpuxalan_r_base.mytest-m64 --option="-v t5.xml xalanc.xsl"'

  spec_dirs[xz]="557.xz_r"
  spec_commands[xz]='-c ./xz_r_base.mytest-m64 --option="input.combined.xz 250 a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf 40401484 41217675 7"'

  spec_dirs[gcc]="502.gcc_r"
  spec_commands[gcc]='-c ./cpugcc_r_base.mytest-m64 --option="ref32.c -O3 -fselective-scheduling -fselective-scheduling2 -o ref32.opts-O3_-fselective-scheduling_-fselective-scheduling2.s"'

  spec_dirs[leela]="541.leela_r"
  spec_commands[leela]='-c ./leela_r_base.mytest-m64 --option="ref.sgf"'

  spec_dirs[exchange2]="548.exchange2_r"
  spec_commands[exchange2]='-c ./exchange2_r_base.mytest-m64 --option="6"'


else
  # SPEC CPU 2006
  spec_dirs[mcf]="mcf"
  spec_commands[mcf]='-c ./mcf_base.x86_64_sse --option="inp.in"'
  spec_dirs[libquantum]="libquantum"
  spec_commands[libquantum]='-c ./libquantum_base.x86_64_sse --option="1397 8"'
  spec_dirs[omnetpp]="omnetpp"
  spec_commands[omnetpp]='-c ./omnetpp_base.x86_64_sse --option="omnetpp.ini"'
  spec_dirs[sjeng]="sjeng"
  spec_commands[sjeng]='-c ./sjeng_base.x86_64_sse --option="input/ref.txt"'
  spec_dirs[astar]="astar"
  spec_commands[astar]='-c ./astar_base.x86_64_sse --option="rivers.cfg"'
  spec_dirs[milc]="milc"
  spec_commands[milc]='-c ./milc_base.x86_64_sse -i input/su3imp.in'
fi

# graph500 测试命令
graph500_command='-c '"$graph500_dir"'/seq-csr --option="-s 20 -e 18"'

# 并行控制
max_jobs=60

# 检查 gem5 binary
if [ ! -f "$gem5_dir/build/X86/gem5.opt" ]; then
  echo "Error: gem5 binary not found at $gem5_dir/build/X86/gem5.opt"
  exit 1
fi

is_memory_sufficient() {
  local free_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local free_memory_percentage=$((free_memory_kb * 100 / total_memory_kb))
  [ "$free_memory_percentage" -gt 35 ]
}

# 获取 benchmark 的运行目录
get_test_dir() {
  local test_name=$1
  local bench_dir=${spec_dirs[$test_name]}
  if [ "$spec_version" = "2017" ]; then
    echo "$spec_base_dir/$bench_dir/$spec_run_suffix"
  else
    echo "$spec_base_dir/$bench_dir"
  fi
}

process_gem5_test() {
  local cache_type=$1 wl_type=$2 swap_time=$3 pre=$4
  local dt=$5 rt_group=$6 max_inst=$7 hbm_size=$8 rt=$9

  local output_dir="$output_base_dir/cache${cache_type}_wl${wl_type}_swap${swap_time}_pre${pre}_I${max_inst}_hbm${hbm_size}_rt${rt}"
  mkdir -p "$output_dir"

  local hybrid_flag="false"
  [ "$rt" -ne 0 ] && hybrid_flag="true"

  local cmd="$gem5_dir/build/X86/gem5.opt --outdir=$output_dir -re $gem5_script"
  cmd+=" -c /home/chen/cpp_test/workload1 --cpu-type TimingSimpleCPU --cpu-clock 3GHz"
  cmd+=" --cache-type=$cache_type --wl-type=$wl_type --swap-time=$swap_time"
  cmd+=" --hbm-size=$hbm_size --pre=$pre -I $max_inst --hybird $hybrid_flag"
  cmd+=" --caches --l1d_size 16kB --l1i_size 64kB --mem-type SimpleMemory --mem-size 4GB"
  [ "$cache_type" -eq 1 ] && cmd+=" --rt-dt=$dt --rt-group=$rt_group"

  echo "Executing: $cmd"
  eval $cmd
}

process_spec_test() {
  local test_name=$1 cache_type=$2 wl_type=$3 swap_time=$4 pre=$5
  local dt=$6 rt_group=$7 max_inst=$8 hbm_size=$9 rt=${10}

  local spec_command=${spec_commands[$test_name]}
  if [ -z "$spec_command" ]; then
    echo "Error: No command for $test_name" | tee -a error_log.txt
    return
  fi

  local output_dir="$output_base_dir/${test_name}_cache${cache_type}_wl${wl_type}_swap${swap_time}_pre${pre}_I${max_inst}_hbm${hbm_size}_rt${rt}"
  [ "$cache_type" -eq 1 ] && output_dir+="_dt${dt}_rtgroup${rt_group}"
  mkdir -p "$output_dir"

  # 跳过已完成的测试
  if [ -f "$output_dir/stats.txt" ] && [ -s "$output_dir/stats.txt" ]; then
    echo "Skipping $test_name (stats.txt exists)"
    return
  fi

  local test_dir
  test_dir=$(get_test_dir "$test_name")
  if [ ! -d "$test_dir" ]; then
    echo "Error: Test directory not found: $test_dir" | tee -a error_log.txt
    return
  fi
  cd "$test_dir"

  local hybrid_flag="false"
  [ "$rt" -ne 0 ] && hybrid_flag="true"

  local cmd="$gem5_dir/build/X86/gem5.opt --outdir=$output_dir -re $gem5_script"
  cmd+=" $spec_command --cpu-type TimingSimpleCPU --cpu-clock 3GHz"
  cmd+=" --cache-type=$cache_type --wl-type=$wl_type --swap-time=$swap_time"
  cmd+=" --hbm-size=$hbm_size --pre=$pre -I $max_inst --hybird $hybrid_flag"
  cmd+=" --caches --l1d_size 16kB --l1i_size 64kB --mem-type SimpleMemory --mem-size 4GB"
  [ "$cache_type" -eq 1 ] && cmd+=" --rt-dt=$dt --rt-group=$rt_group"

  echo "Executing: $cmd"
  eval $cmd
}

# ===== 主循环 =====
swap_times=(2048)

for rt in "${rt_values[@]}"; do
  if [ "$rt" -eq 0 ]; then
    process_gem5_test 0 3 2048 0 0 0 "${max_inst_values[0]}" "${hbm_sizes[0]}" 0 &
  else
    for wl_type in "${yu_wl_types[@]}"; do
      if [ "$wl_type" -eq 3 ]; then
        pre_values=(0); cache_types=(0)
      else
        pre_values=("${yu_pre_values[@]}"); cache_types=("${yu_cache_types[@]}")
      fi
      for cache_type in "${cache_types[@]}"; do
        local_pre_values=("${pre_values[@]}")
        [ "$cache_type" -eq 0 ] && local_pre_values=(0)
        for pre in "${local_pre_values[@]}"; do
          for max_inst in "${max_inst_values[@]}"; do
            for hbm_size in "${hbm_sizes[@]}"; do
              if [ "$cache_type" -eq 1 ]; then
                for dt in "${dt_values[@]}"; do
                  for rt_group in "${rt_group_values[@]}"; do
                    process_gem5_test "$cache_type" "$wl_type" "${swap_times[0]}" "$pre" "$dt" "$rt_group" "$max_inst" "$hbm_size" "$rt" &
                  done
                done
              else
                process_gem5_test "$cache_type" "$wl_type" "${swap_times[0]}" "$pre" 0 0 "$max_inst" "$hbm_size" "$rt" &
              fi
            done
          done
        done
      done
    done
  fi
done

wait
echo "All tasks completed."
