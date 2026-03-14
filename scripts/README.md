# scripts - gem5 模拟批量测试脚本

RTcache 项目的 gem5 模拟实验脚本集，用于遍历参数空间运行 SPEC CPU / graph500 基准测试。

## 脚本说明

| 脚本 | 用途 | 默认 benchmark |
|------|------|----------------|
| `gem5-test.sh` | 基础参数遍历（cache-type/wl-type/RT 组合） | workload（自定义程序） |
| `gem5-omnetpp.sh` | 单 benchmark 精细测试（含 fast-forward + L2） | mcf |
| `gem5-graph.sh` | graph500 参数遍历（含 fast-forward + L2） | graph500 seq-csr |

## 快速开始

```bash
# 确保 gem5 已编译
ls ../build/X86/gem5.opt

# 运行基础测试
./gem5-test.sh /path/to/output

# 运行 mcf 精细测试
./gem5-omnetpp.sh /path/to/output

# 运行 graph500 测试
./gem5-graph.sh /path/to/output
```

## SPEC CPU 版本配置

所有脚本默认使用 **SPEC CPU 2017**。如需切换到 SPEC CPU 2006，编辑脚本顶部的配置区：

### 当前配置 (SPEC CPU 2017)

```bash
spec_version="2017"
spec_base_dir="/home/chen/speccpu2017/benchspec/CPU"
spec_run_suffix="run/run_base_refrate_mytest-m64.0000"
```

### 切换到 SPEC CPU 2006

如果获取了 SPEC CPU 2006，按以下步骤配置：

1. 安装 SPEC CPU 2006 到 `/home/chen/spec2006`
2. 编译所有 benchmark：
   ```bash
   cd /home/chen/spec2006
   source shrc
   runspec --config=myconfig.cfg --action=build all
   ```
3. 确认每个 benchmark 目录下有可执行文件，如 `mcf/mcf_base.x86_64_sse`
4. 修改脚本配置：
   ```bash
   # 注释掉 2017 配置
   # spec_version="2017"
   # spec_base_dir="/home/chen/speccpu2017/benchspec/CPU"
   # spec_run_suffix="run/run_base_refrate_mytest-m64.0000"

   # 启用 2006 配置
   spec_version="2006"
   spec_base_dir="/home/chen/spec2006"
   spec_run_suffix=""
   ```

### SPEC CPU 2006 目录结构要求

```
/home/chen/spec2006/
├── mcf/
│   ├── mcf_base.x86_64_sse    # 编译后的可执行文件
│   └── inp.in                  # 输入文件
├── omnetpp/
│   ├── omnetpp_base.x86_64_sse
│   └── omnetpp.ini
├── astar/
│   ├── astar_base.x86_64_sse
│   └── rivers.cfg
├── sjeng/
│   ├── sjeng_base.x86_64_sse
│   └── input/ref.txt
├── libquantum/
│   └── libquantum_base.x86_64_sse
└── milc/
    ├── milc_base.x86_64_sse
    └── input/su3imp.in
```

每个目录需包含可执行文件和对应的输入文件（从 SPEC 的 run 目录拷贝）。

## SPEC CPU 2017 当前状态

### 已编译的 benchmark

| 短名 | 全名 | 可执行文件 | 内存特征 |
|------|------|-----------|---------|
| mcf | 505.mcf_r | mcf_r_base.mytest-m64 | 高 LLC miss，内存密集 |
| lbm | 519.lbm_r | lbm_r_base.mytest-m64 | 流式访问，内存密集 |
| perlbench | 500.perlbench_r | perlbench_r_base.mytest-m64 | 混合访问 |
| namd | 508.namd_r | namd_r_base.mytest-m64 | 浮点，中等内存 |
| cactuBSSN | 507.cactuBSSN_r | cactusBSSN_r_base.mytest-m64 | 浮点，内存密集 |
| parest | 510.parest_r | parest_r_base.mytest-m64 | 浮点 |
| povray | 511.povray_r | povray_r_base.mytest-m64 | 浮点 |

### 编译缺失的 benchmark

以下 benchmark 与 SPEC2006 对应但尚未编译：

```bash
# 进入 SPEC2017 目录
cd /home/chen/speccpu2017
source shrc

# 编译单个 benchmark (以 omnetpp 为例)
runcpu --config=mytest.cfg --action=build 520.omnetpp_r

# 编译后需要 setup run directory
runcpu --config=mytest.cfg --action=setup 520.omnetpp_r

# 批量编译所有整数 benchmark
runcpu --config=mytest.cfg --action=build intrate
```

| SPEC2006 | SPEC2017 对应 | 编译状态 |
|----------|--------------|---------|
| omnetpp | 520.omnetpp_r | 未编译 |
| sjeng | 531.deepsjeng_r | 未编译 |
| xalancbmk | 523.xalancbmk_r | 未编译 |
| — | 557.xz_r (新增) | 未编译 |
| libquantum | (已移除) | — |
| astar | (已移除) | — |
| milc | (已移除) | — |

## gem5 参数说明

| 参数 | 含义 | 取值 |
|------|------|------|
| `--cache-type` | 缓存架构 | 0=基线, 1=RT, 2=HBM, 3=RT+HBM |
| `--wl-type` | 写入策略 | 0=WriteBack, 1=WT-32, 2=WT-10, 3=NoCache |
| `--swap-time` | 交换延迟 | 因 wl-type 而异 |
| `--hbm-size` | HBM 容量 | 4kB, 8kB, 16kB, 32kB |
| `--pre` | 硬件预取 | 0=关, 1=开 |
| `--hybird` | RT混合模式 | true/false |
| `-I` | 最大指令数 | 通常 1e8 ~ 1.5e9 |
| `--fast-forward` | 跳过指令数 | 预热用，通常 1e8 ~ 2e8 |
| `--RT` | Region Table | 0=关, 1=开 |
| `--rt-dt` | RT dirty threshold | 仅 cache-type=1 |
| `--rt-group` | RT 分组大小 | 仅 cache-type=1 |
