# 编译器
CXX = g++

# 默认构建模式为发布
BUILD = release

# 编译选项
ifeq ($(BUILD),debug)
CFLAGS = -Wall -Wextra -g -O0
LDFLAGS =
else
CFLAGS = -Wall -Wextra -O3 -march=native -flto -funroll-loops -finline-functions -ffast-math -fstrict-aliasing -pg
LDFLAGS = -flto=auto -fuse-linker-plugin -Wl,-O3 -Wl,--as-needed -Wl,--gc-sections,-lboost_program_options
endif

# 可执行文件名称
executables = test

# 伪目标
.PHONY: all clean

# 默认目标
all: $(executables)

# 链接可执行文件
test: hit_test.o no_cache.o rtcache.o _way_cache.o SB_TLB.o twl.o climber.o
	$(CXX) $^ $(LDFLAGS) -o $@

# 编译源文件为对象文件
%.o: %.cpp
	$(CXX) $(CFLAGS) -c $< -o $@

%.o: %.cc
	$(CXX) $(CFLAGS) -c $< -o $@

# 清理目标
clean:
	rm -f *.o $(executables)
