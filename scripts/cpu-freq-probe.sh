#!/bin/bash
# CPU 实际频率探针 —— 用于对比不同机型/BIOS 设置下的真实核心频率
# 原理：mulsd（标量双精度乘法）在 Intel 近代表上固定 4 周期延迟；
#       把乘法写进内联汇编 => 编译器无法折叠，测得的就是纯依赖链周期数。
# 用法：bash cpu-freq-probe.sh
set -u
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/fb.c" <<'EOF'
#include <stdio.h>
#include <time.h>
#define S __asm__ __volatile__("mulsd %1, %0" : "+x"(d) : "x"(k));
int main(void){
    struct timespec t0,t1; const unsigned long long L=20000000ULL;
    volatile double sink; double d=1.0, k=1.0000000001;
    clock_gettime(CLOCK_MONOTONIC,&t0);
    for(unsigned long long i=0;i<L;i++){
        S S S S S S S S S S S S S S S S
        S S S S S S S S S S S S S S S S
    }
    clock_gettime(CLOCK_MONOTONIC,&t1); sink=d;
    double sec=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
    double cyc=(double)L*32.0*4.0;
    printf("%.2f", cyc/sec/1e9);
    return 0;
}
EOF
clang -O2 -o "$TMP/fb" "$TMP/fb.c" || { echo "编译失败（需要 Xcode 命令行工具）"; exit 1; }
echo "机型: $(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/{print $2}')"
echo -n "单线程实测核心频率: "; "$TMP/fb"; echo " GHz"
echo "8 线程并发（每线程）:"
for i in 1 2 3 4 5 6 7 8; do printf '  '; "$TMP/fb"; echo ' GHz'; done
echo "参考：i7-12700K 单核睿频 5.0 GHz / 全核约 4.7 GHz"
