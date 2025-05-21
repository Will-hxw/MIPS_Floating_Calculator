.data
    # 欢迎信息
    msg_welcome:    .asciiz "\nWelcome to floating-point calculator by 20230537 Xiaowei Hua.\n"
    # 主菜单提示
    msg_menu:       .asciiz "Menu: 1:Add  2:Sub  3:Mul  4:Div  5:Exit\nSelect: "
    # 输入第一个操作数提示
    msg_op1:        .asciiz "\nFirst operand (decimal): "
    # 输入第二个操作数提示
    msg_op2:        .asciiz "\nSecond operand (decimal): "
    # 二进制输出前缀
    msg_bin:        .asciiz "\nResult in binary: "
    # 十六进制输出前缀
    msg_hex:        .asciiz "\nResult in hex: 0x"
    # 错误信息：上溢、下溢、除零
    msg_overflow:   .asciiz "\nError: overflow!\n"
    msg_underflow:  .asciiz "\nError: underflow!\n"
    msg_divzero:    .asciiz "\nError: divide by zero!\n"
    # 换行
    newline:        .asciiz "\n"
    # 十六进制字符表
    hex_table:      .asciiz "0123456789ABCDEF"

.text
    .globl main
main:
    # 打印欢迎信息
    li   $v0, 4
    la   $a0, msg_welcome
    syscall

Menu:
    # 打印菜单并读取选择
    li   $v0, 4
    la   $a0, msg_menu
    syscall
    li   $v0, 5        # read integer
    syscall
    move $s7, $v0      # 保存选择

    # 验证选择范围1-5
    li   $t0, 1
    blt  $s7, $t0, Menu
    li   $t0, 5
    bgt  $s7, $t0, Menu
    beq  $s7, $t0, Exit

    # 读取第一个浮点数
    li   $v0, 4
    la   $a0, msg_op1
    syscall
    li   $v0, 6        # read float
    syscall
    mfc1 $t0, $f0      # 获取IEEE754位表示

    # 提取第一个浮点数的符号、指数、尾数
    srl  $s0, $t0, 31  # sign bit
    srl  $s1, $t0, 23  # raw exponent bits
    andi $s1, $s1, 0xFF
    andi $s2, $t0, 0x7FFFFF # raw mantissa bits
    # 若指数不为0，则加上隐含1
    bnez $s1, AddImp1
    j    NoAddImp1
AddImp1:
    ori  $s2, $s2, 0x800000
NoAddImp1:

    # 读取第二个浮点数
    li   $v0, 4
    la   $a0, msg_op2
    syscall
    li   $v0, 6
    syscall
    mfc1 $t0, $f0

    # 提取第二个浮点数的符号、指数、尾数
    srl  $s3, $t0, 31
    srl  $s4, $t0, 23
    andi $s4, $s4, 0xFF
    andi $s5, $t0, 0x7FFFFF
    bnez $s4, AddImp2
    j    NoAddImp2
AddImp2:
    ori  $s5, $s5, 0x800000
NoAddImp2:

    # 分支到对应运算
    li   $t0, 1
    beq  $s7, $t0, FP_Add
    li   $t0, 2
    beq  $s7, $t0, FP_Sub
    li   $t0, 3
    beq  $s7, $t0, FP_Mul
    li   $t0, 4
    beq  $s7, $t0, FP_Div
    j    Menu

# ---------------- 浮点加法子程序 ----------------
FP_Add:
    # 对齐指数: 确保 s1 >= s4，否则交换操作数
    sub  $t0, $s1, $s4
    bgez $t0, NoSwapAdd
    # 交换 s0<->s3, s1<->s4, s2<->s5
    move $t9, $s0
    move $s0, $s3
    move $s3, $t9
    move $t9, $s1
    move $s1, $s4
    move $s4, $t9
    move $t9, $s2
    move $s2, $s5
    move $s5, $t9
NoSwapAdd:
    # 右移尾数以对齐指数
    sub  $t0, $s1, $s4
AddAlignLoop:
    beqz $t0, AddCompute
    srl  $s5, $s5, 1
    addi $s4, $s4, 1
    addi $t0, $t0, -1
    j    AddAlignLoop

AddCompute:
    # 判断同号/异号
    xor  $t0, $s0, $s3
    beqz $t0, AddSameSign
    # 异号: 尾数相减
    sub  $t2, $s2, $s5
    move $t1, $s1
    # 若结果为0
    beqz $t2, PrintZero
    # 结果符号处理
    bltz $t2, MakePos1
    move $t0, $s0
    j    NormalizeAdd
MakePos1:
    li   $t0, 1
    sub  $t2, $zero, $t2
    j    NormalizeAdd

AddSameSign:
    # 同号: 尾数相加，保留符号
    add  $t2, $s2, $s5
    move $t1, $s1
    move $t0, $s0
    # 检查是否有进位
    andi $t9, $t2, 0x1000000
    beqz $t9, NormalizeAdd
    # 有进位: 右移一位，指数+1
    srl  $t2, $t2, 1
    addi $t1, $t1, 1
    li   $t9, 255
    beq  $t1, $t9, Overflow

NormalizeAdd:
    # 规格化: 保证尾数最高位(bit23)为1
    li   $t9, 0x800000
    slt  $t8, $t2, $t9
    beqz $t8, BuildResult
    sll  $t2, $t2, 1
    addi $t1, $t1, -1
    beqz $t1, Underflow
    j    NormalizeAdd

# ---------------- 浮点减法: 异或符号后加法 ----------------
FP_Sub:
    xori $s3, $s3, 1
    j    FP_Add

# ---------------- 浮点乘法子程序 ----------------
FP_Mul:
    # 若任一为0，则直接返回0
    beqz $s1, MulZero
    beqz $s4, MulZero
    # 指数相加后减127偏移
    add  $t1, $s1, $s4
    addi $t1, $t1, -127
    # 尾数相乘: mult hi:lo
    mult $s2, $s5
    mfhi $t9
    mflo $t8
    # 取 hi<<9 | lo>>23 作为结果尾数
    sll  $t9, $t9, 9
    srl  $t8, $t8, 23
    or   $t2, $t9, $t8
    # 规格化检查
    andi $t9, $t2, 0x800000
    beqz $t9, NoCarryMul
    srl  $t2, $t2, 1
    addi $t1, $t1, 1
NoCarryMul:
    # 检查溢出/下溢
    li   $t9, 254
    bgt  $t1, $t9, Overflow
    beqz $t1, Underflow
    # 计算符号
    xor  $t0, $s0, $s3
    j    BuildResult

MulZero:
    # 返回+0
    li   $t0, 0
    li   $t1, 0
    li   $t2, 0
    j    BuildResult

# ---------------- 浮点除法子程序 ----------------
FP_Div:
    # 检查除零
    beqz $s5, DivError
    # 指数相减后加127偏移
    sub  $t1, $s1, $s4
    addi $t1, $t1, 127
    # 尾数除法
    div  $s2, $s5
    mflo $t2
DivNormLoop:
    # 规格化: 确保bit23=1
    andi $t9, $t2, 0x800000
    bnez $t9, AfterDivNorm
    sll  $t2, $t2, 1
    addi $t1, $t1, -1
    beqz $t1, Underflow
    j    DivNormLoop
AfterDivNorm:
    # 检查上溢
    li   $t9, 254
    bgt  $t1, $t9, Overflow
    # 计算符号
    xor  $t0, $s0, $s3
    j    BuildResult

DivError:
    # 打印除零错误并返回菜单
    li   $v0, 4
    la   $a0, msg_divzero
    syscall
    j    Menu

# ---------------- 构造并打印结果 ----------------
PrintZero:
    # 构造+0
    li   $t0, 0
    li   $t1, 0
    li   $t2, 0
    j    BuildResult

Overflow:
    # 打印上溢错误并返回菜单
    li   $v0, 4
    la   $a0, msg_overflow
    syscall
    j    Menu

Underflow:
    # 打印下溢错误并返回菜单
    li   $v0, 4
    la   $a0, msg_underflow
    syscall
    j    Menu

BuildResult:
    # 重建32位原始位: sign<<31 | exp<<23 | mantissa
    sll  $t6, $t0, 31
    sll  $t7, $t1, 23
    andi $t2, $t2, 0x7FFFFF
    or   $t7, $t6, $t7
    or   $t7, $t7, $t2
    # 调用打印二进制和十六进制
    jal  PrintBinary
    jal  PrintHex
    j    Menu

# ---------------- 打印二进制子程序 ----------------
PrintBinary:
    # 打印前缀
    li   $v0, 4
    la   $a0, msg_bin
    syscall
    # 逐位打印32位
    li   $t8, 32
PB_Loop:
    beqz $t8, PB_End
    addi $t8, $t8, -1
    # 使用可变移位指令 srlv
    srlv $t9, $t7, $t8
    andi $t9, $t9, 1
    li   $v0, 11
    addi $t9, $t9, '0'
    move $a0, $t9
    syscall
    j    PB_Loop
PB_End:
    # 换行
    li   $v0, 4
    la   $a0, newline
    syscall
    jr   $ra

# ---------------- 打印十六进制子程序 ----------------
PrintHex:
    # 打印前缀
    li   $v0, 4
    la   $a0, msg_hex
    syscall
    # 逐位打印8个十六进制字符
    li   $t8, 8
PH_Loop:
    beqz $t8, PH_End
    addi $t8, $t8, -1
    # 计算移位量 = t8*4
    sll  $t9, $t8, 2
    # 使用可变移位指令 srlv
    srlv $t0, $t7, $t9
    andi $t0, $t0, 0xF
    la   $t1, hex_table
    add  $t1, $t1, $t0
    lb   $t1, 0($t1)
    li   $v0, 11
    move $a0, $t1
    syscall
    j    PH_Loop
PH_End:
    # 换行
    li   $v0, 4
    la   $a0, newline
    syscall
    jr   $ra

# ---------------- 退出程序 ----------------
Exit:
    li   $v0, 4
    la   $a0, msg_welcome
    syscall
    li   $v0, 10
    syscall