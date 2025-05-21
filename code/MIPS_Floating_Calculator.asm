# IEEE 754单精度浮点数计算器
# 使用软件方法实现IEEE 754单精度浮点数的表示及运算功能
# 支持十进制实数输入，IEEE754单精度表示，二进制和十六进制输出
# 实现浮点数的加减乘除运算
# 使用MIPS汇编指令，不使用浮点指令，只使用整数运算指令

.data
    # -------------------- 字符串常量区 --------------------
    # 欢迎信息
    msg_welcome:    .asciiz "\nWelcome to IEEE 754 Calculator by 20230537 Xiaowei Hua!\n"
    # 主菜单提示
    msg_menu:       .asciiz "\nMenu Options:\n1. Addition (+)\n2. Subtraction (-)\n3. Multiplication (*)\n4. Division (/)\n5. Exit\nPlease select (1-5): "
    # 输入第一个操作数提示
    msg_op1:        .asciiz "\nEnter first floating-point value: "
    # 输入第二个操作数提示
    msg_op2:        .asciiz "\nEnter second floating-point value: "
    # 结果提示
    msg_result:     .asciiz "\nCalculation Result:\n"
    # 二进制输出前缀
    msg_bin:        .asciiz "Binary result: "
    # 十六进制输出前缀
    msg_hex:        .asciiz "Hexadecimal result: 0x"
    # 错误信息：上溢、下溢、除零
    msg_overflow:   .asciiz "\nError: overflow detected!\n"
    msg_underflow:  .asciiz "\nError: underflow detected!\n"
    msg_divzero:    .asciiz "\nError: division by zero!\n"
    # 无效输入
    msg_invalid:    .asciiz "\nInvalid input! Please try again.\n"
    # 退出消息
    msg_exit:       .asciiz "\nThank you for using IEEE 754 Calculator. Goodbye!\n"
    # 换行符
    newline:        .asciiz "\n"
    # 十六进制字符表
    hex_table:      .asciiz "0123456789ABCDEF"

.text
    .globl main

# -------------------- 主程序入口 --------------------
main:
    # 打印欢迎信息
    li   $v0, 4
    la   $a0, msg_welcome
    syscall

# -------------------- 主菜单循环 --------------------
Menu:
    # 显示菜单并读取选择
    li   $v0, 4
    la   $a0, msg_menu
    syscall
    
    # 读取用户选择
    li   $v0, 5        # syscall 5: 读取整数
    syscall
    move $s7, $v0      # 将用户选择保存到$s7
    
    # 验证选择范围1-5
    li   $t0, 1
    blt  $s7, $t0, InvalidInput  # 小于1，无效输入
    li   $t0, 5
    bgt  $s7, $t0, InvalidInput  # 大于5，无效输入
    beq  $s7, $t0, Exit          # 等于5，退出程序
    
    # 选择有效，继续读取浮点数操作数
    j    ReadOperands

# -------------------- 无效输入处理 --------------------
InvalidInput:
    # 打印无效输入消息
    li   $v0, 4
    la   $a0, msg_invalid
    syscall
    j    Menu          # 返回主菜单

# -------------------- 读取操作数 --------------------
ReadOperands:
    # 读取第一个浮点数
    li   $v0, 4
    la   $a0, msg_op1
    syscall
    
    # 读取第一个浮点数（使用MARS提供的syscall 6）
    li   $v0, 6        # syscall 6: 读取浮点数
    syscall
    mfc1 $t0, $f0      # 将浮点寄存器中的IEEE 754位表示移到整数寄存器
    
    # 提取第一个浮点数的符号位、指数位和尾数位
    srl  $s0, $t0, 31  # 符号位: 第31位
    srl  $s1, $t0, 23  # 提取原始指数位（未减去偏移量）
    andi $s1, $s1, 0xFF  # 保留低8位（指数位）
    andi $s2, $t0, 0x7FFFFF  # 提取原始尾数位（低23位）
    
    # 如果指数不为0，则为规格化数，将隐含的前导1添加到尾数中
    # 如果指数为0，则为非规格化数或零，不添加前导1
    bnez $s1, AddImplicit1
    j    Continue1
    
AddImplicit1:
    # 将隐含的前导1添加到尾数中（设置尾数的第23位为1）
    ori  $s2, $s2, 0x800000
    
Continue1:
    # 读取第二个浮点数
    li   $v0, 4
    la   $a0, msg_op2
    syscall
    
    # 读取第二个浮点数
    li   $v0, 6
    syscall
    mfc1 $t0, $f0
    
    # 提取第二个浮点数的符号位、指数位和尾数位
    srl  $s3, $t0, 31  # 符号位
    srl  $s4, $t0, 23  # 指数位
    andi $s4, $s4, 0xFF
    andi $s5, $t0, 0x7FFFFF  # 尾数位
    
    # 如果指数不为0，则添加隐含的前导1
    bnez $s4, AddImplicit2
    j    Continue2
    
AddImplicit2:
    # 将隐含的前导1添加到尾数中
    ori  $s5, $s5, 0x800000
    
Continue2:
    # 根据用户的选择分支到相应的操作
    li   $t0, 1
    beq  $s7, $t0, FloatAdd     # 选择1，执行加法
    li   $t0, 2
    beq  $s7, $t0, FloatSub     # 选择2，执行减法
    li   $t0, 3
    beq  $s7, $t0, FloatMul     # 选择3，执行乘法
    li   $t0, 4
    beq  $s7, $t0, FloatDiv     # 选择4，执行除法
    
    # 如果到达这里，说明选择无效，返回菜单
    j    Menu

# -------------------- 浮点数加法 --------------------
FloatAdd:
    # 对齐操作数指数：确保 s1 >= s4，否则交换操作数
    sub  $t0, $s1, $s4              # 计算指数差值
    bgez $t0, FloatAdd_NoSwap      # 如果第一个操作数指数更大，不需要交换
    
    # 交换操作数（符号位、指数位、尾数位）
    move $t9, $s0                   # 临时保存第一个操作数的符号位
    move $s0, $s3                   # 将第二个操作数的符号位移到第一个的位置
    move $s3, $t9                   # 将保存的第一个操作数的符号位移到第二个的位置
    
    move $t9, $s1                   # 临时保存第一个操作数的指数位
    move $s1, $s4                   # 将第二个操作数的指数位移到第一个的位置
    move $s4, $t9                   # 将保存的第一个操作数的指数位移到第二个的位置
    
    move $t9, $s2                   # 临时保存第一个操作数的尾数位
    move $s2, $s5                   # 将第二个操作数的尾数位移到第一个的位置
    move $s5, $t9                   # 将保存的第一个操作数的尾数位移到第二个的位置

FloatAdd_NoSwap:
    # 此时s1一定大于等于s4
    # 计算指数差值并右移第二个浮点数的尾数以对齐小数点
    sub  $t0, $s1, $s4              # 计算指数差值

    # 对齐小数点循环
    # 第二个浮点数的尾数右移指数差值位
    # 由于指数差值可能很大，所以可能需要多次移位
    # 注意：如果移位超过尾数位数，则尾数变为0
    li   $t9, 24                    # 最多右移24位（超过23位尾数）就会变为0
    bgt  $t0, $t9, FloatAdd_ZeroS5  # 如果指数差值大于24，则直接将第二个尾数置为0

FloatAdd_AlignLoop:
    beqz $t0, FloatAdd_Aligned     # 如果指数差值为0，表示已对齐
    srl  $s5, $s5, 1               # 尾数右移1位
    addi $t0, $t0, -1              # 指数差值减1
    j    FloatAdd_AlignLoop        # 继续对齐循环

# 如果指数差值过大，一个浮点数将被完全右移出去，等价于变成了0
FloatAdd_ZeroS5:
    li   $s5, 0                     # 将第二个尾数置为0

FloatAdd_Aligned:
    # 判断同号/异号
    xor  $t0, $s0, $s3              # 相同符号异或结果为0，不同符号结果为1
    beqz $t0, FloatAdd_SameSign     # 如果两数符号相同，跳转到同号处理
    j    FloatAdd_DiffSign          # 如果两数符号不同，跳转到异号处理

# 异号加法（实际上是做减法）
FloatAdd_DiffSign:
    # 记录结果的指数（尾数对齐后，用较大的指数）
    move $t1, $s1                   # 结果的指数 = 第一个操作数的指数
    # 尾数相减
    sub  $t2, $s2, $s5              # 结果的尾数 = 第一个操作数的尾数 - 第二个操作数的尾数
    # 如果结果为0，添加特殊情况处理
    beqz $t2, PrintZero             # 如果结果为0，直接跳转到打印零处理
    # 判断尾数相减后的符号
    bltz $t2, FloatAdd_MantissaNeg  # 如果尾数相减结果为负数，跳转到负数处理
    # 尾数相减结果为正数，所以结果符号和第一个操作数的符号相同
    move $t0, $s0                   # 结果符号 = 第一个操作数符号
    j    FloatAdd_Normalize         # 跳转到规格化处理

# 尾数相减结果为负数的处理
FloatAdd_MantissaNeg:
    # 尾数取绝对值（取负）
    sub  $t2, $zero, $t2            # 尾数取负（取绝对值）
    # 结果符号与第二个操作数符号相同
    move $t0, $s3                   # 结果符号 = 第二个操作数符号
    j    FloatAdd_Normalize         # 跳转到规格化处理

# 同号加法
FloatAdd_SameSign:
    # 记录结果符号（与两个操作数符号相同）
    move $t0, $s0                   # 结果符号 = 第一个操作数符号
    # 记录结果指数（与第一个操作数指数相同）
    move $t1, $s1                   # 结果指数 = 第一个操作数指数
    # 尾数相加
    add  $t2, $s2, $s5              # 结果尾数 = 第一个操作数尾数 + 第二个操作数尾数
    # 检查是否有进位（尾数有效位为23位，第24位若为1则表示有进位）
    andi $t9, $t2, 0x1000000        # 检查第24位是否为1
    beqz $t9, FloatAdd_Normalize    # 如果没有进位，直接跳转到规格化处理
    # 处理进位情况：尾数右移1位，指数加1
    srl  $t2, $t2, 1                # 尾数右移1位
    addi $t1, $t1, 1                # 指数加1
    # 检查指数是否上溢
    li   $t9, 255
    beq  $t1, $t9, Overflow         # 如果指数达到255，则发生上溢

# 浮点数规格化：保证尾数最高位（第23位）为1
FloatAdd_Normalize:
    # 判断尾数的最高位是否为1
    li   $t9, 0x800000              # 探测尾数的第23位（隐含位）
    and  $t8, $t2, $t9              # 与掉其他位，只保留第23位
    bnez $t8, FloatAdd_BuildResult  # 如果隐含位已经为1，则跳转到构建结果

    # 如果到达这里，说明隐含位为0，需要左移尾数
    # 如果尾数为0，则表示结果为0
    beqz $t2, PrintZero             # 如果尾数为0，直接跳转到打印零处理

    # 循环左移尾数直到隐含位为1
FloatAdd_NormalizeLoop:
    beqz $t1, Underflow             # 如果指数为0，发生下溢
    sll  $t2, $t2, 1                # 尾数左移1位
    addi $t1, $t1, -1               # 指数减1
    andi $t9, $t2, 0x800000         # 检查隐含位是否为1
    beqz $t9, FloatAdd_NormalizeLoop # 如果隐含位仍为0，继续规格化

# 构建 IEEE 754 结果
FloatAdd_BuildResult:
    # 结果已经规格化，构建最终的IEEE 754表示
    # 重组全部位：符号位 << 31 | 指数位 << 23 | 尾数位
    # 先将尾数的隐含位（第23位）清零
    andi $t2, $t2, 0x7FFFFF         # 只保留尾数的低23位
    # 然后重组IEEE 754的所有部分
    sll  $t6, $t0, 31               # 符号位移位到最高位
    sll  $t7, $t1, 23               # 指数位移位到正确位置
    or   $t7, $t6, $t7              # 组合符号位和指数位
    or   $t7, $t7, $t2              # 组合尾数位
    # 打印计算结果
    j    PrintResult                # 跳转到打印结果子程序

# -------------------- 浮点数减法 --------------------
FloatSub:
    # 浮点数减法可以通过取反第二个浮点数的符号位来实现，然后执行加法
    xori $s3, $s3, 1                # 取反第二个浮点数的符号位
    j    FloatAdd                   # 跳转到浮点数加法子程序

# -------------------- 浮点数乘法 --------------------
FloatMul:
    # 特殊情况处理：如果任一数为零，则结果为零
    # 检查第一个浮点数是否为零
    beqz $s1, FloatMul_Zero         # 如果第一个浮点数的指数为0
    beqz $s2, FloatMul_Zero         # 或者尾数为0
    
    # 检查第二个浮点数是否为零
    beqz $s4, FloatMul_Zero         # 如果第二个浮点数的指数为0
    beqz $s5, FloatMul_Zero         # 或者尾数为0
    
    # 计算结果的符号位：符号位异或运算
    xor  $t0, $s0, $s3              # 结果的符号位 = 第一个浮点数的符号位 异或 第二个浮点数的符号位
    
    # 计算结果的指数位：两个指数相加再减去偏移量127
    add  $t1, $s1, $s4              # 结果的指数位 = 第一个浮点数的指数位 + 第二个浮点数的指数位
    addi $t1, $t1, -127             # 减去偏移量127
    
    # 检查指数溢出
    bgtz $t1, FloatMul_CheckOverflow # 可能存在上溢
    bltz $t1, FloatMul_CheckUnderflow # 可能存在下溢
    j    FloatMul_ComputeMantissa   # 指数在有效范围，直接计算尾数
    
FloatMul_CheckOverflow:
    # 检查指数上溢
    li   $t9, 254                  # 设置指数的最大值（254）
    bgt  $t1, $t9, Overflow         # 如果指数大于254，则上溢
    j    FloatMul_ComputeMantissa   # 指数未上溢，计算尾数
    
FloatMul_CheckUnderflow:
    # 检查指数下溢
    li   $t9, -126                 # 设置指数的最小值（-126）
    blt  $t1, $t9, Underflow        # 如果指数小于-126，则下溢
    # 将负值指数调整为0（非规格化数）
    beq  $t1, $t9, FloatMul_Denormal # 如果指数等于-126，则可能是非规格化数
    addi $t1, $t1, 127             # 将指数调整为移码表示
    j    FloatMul_ComputeMantissa
    
FloatMul_Denormal:
    # 非规格化数处理，这里粒化处理为直接说是下溢
    # 方便起见直接说是下溢，实际应用中应该做非规格化数的处理
    j    Underflow

FloatMul_ComputeMantissa:
    # 计算结果的尾数位：两个尾数相乘
    # 在MIPS中，mult指令会将两个32位整数相乘，结果存于LO和HI寄存器中
    # 尾数相乘会生戩46位，需要特殊处理
    mult $s2, $s5                  # 尾数相乘：s2 * s5
    mfhi $t9                       # 获取高32位到t9
    mflo $t8                       # 获取低32位到t8
    
    # 由于每个尾数是1.xxx形式，相乘后结果是(1...3)点xxx
    # 所以需要处理可能的进位，并保留最重要的23位
    # 先检查是否有进位（结果是2.xxx还是1.xxx）
    srl  $t2, $t9, 9                # 检查高位是否为0
    bnez $t2, FloatMul_Normalize    # 不为0，需要归一化
    
    # 取前25位作为尾数（包含隐含位1）
    # 需要拼接高位和低位
    sll  $t2, $t9, 9                # 高位左移9位
    srl  $t3, $t8, 23               # 低位右移23位
    or   $t2, $t2, $t3              # 将两部分拼接起来
    j    FloatMul_RoundCheck        # 检查舍入
    
FloatMul_Normalize:
    # 结果为2.xxx，需要将尾数右移1位，指数加1
    # 取前25位作为尾数，但要右移一位
    sll  $t2, $t9, 8                # 高位左移8位（相当于左移9再右移1）
    srl  $t3, $t8, 24               # 低位右移24位（相当于右移23再右移1）
    or   $t2, $t2, $t3              # 将两部分拼接起来
    addi $t1, $t1, 1                # 指数加1
    # 再次检查指数上溢
    li   $t9, 254
    bgt  $t1, $t9, Overflow         # 如果指数大于254，则上溢
    
FloatMul_RoundCheck:
    # 检查艘位最高位是否为1
    andi $t9, $t2, 0x800000
    beqz $t9, FloatMul_NormalizeLoop # 如果隐含位为0，需要左移规格化
    j    FloatMul_BuildResult       # 已经规格化，直接构建结果
    
FloatMul_NormalizeLoop:
    # 如果尾数的隐含位为0，需要对尾数进行规格化
    beqz $t1, Underflow             # 检查指数下溢
    beqz $t2, PrintZero             # 如果尾数为0，结果为0
    sll  $t2, $t2, 1                # 尾数左移1位
    addi $t1, $t1, -1               # 指数减1
    andi $t9, $t2, 0x800000        # 检查隐含位是否为1
    beqz $t9, FloatMul_NormalizeLoop # 如果隐含位为0，继续规格化
    
FloatMul_BuildResult:
    # 将尾数的隐含位清零并重组IEEE 754表示
    andi $t2, $t2, 0x7FFFFF         # 清除隐含位，只保留尾数的低23位
    sll  $t6, $t0, 31               # 符号位移位到最高位
    sll  $t7, $t1, 23               # 指数位移位到正确位置
    or   $t7, $t6, $t7              # 组合符号位和指数位
    or   $t7, $t7, $t2              # 组合尾数位
    j    PrintResult                # 跳转到打印结果
    
FloatMul_Zero:
    # 如果任一数为零，则结果为零
    j    PrintZero                  # 跳转到打印零子程序

# -------------------- 浮点数除法 --------------------
FloatDiv:
    # 检查除数是否为零
    beqz $s4, DivideByZero         # 如果第二个浮点数的指数为0
    beqz $s5, DivideByZero         # 或者尾数为0
    
    # 如果被除数为零，结果为零
    beqz $s1, PrintZero            # 如果第一个浮点数的指数为0
    beqz $s2, PrintZero            # 或者尾数为0
    
    # 计算结果的符号位：符号位异或运算
    xor  $t0, $s0, $s3              # 结果的符号位 = 第一个浮点数的符号位 异或 第二个浮点数的符号位
    
    # 计算结果的指数位：第一个指数 - 第二个指数 + 127（偏移量）
    sub  $t1, $s1, $s4              # 结果的指数位 = 第一个浮点数的指数位 - 第二个浮点数的指数位
    addi $t1, $t1, 127             # 加上偏移量127
    
    # 检查指数溢出
    bgtz $t1, FloatDiv_CheckOverflow  # 可能存在上溢
    bltz $t1, FloatDiv_CheckUnderflow # 可能存在下溢
    j    FloatDiv_ComputeMantissa   # 指数在有效范围，直接计算尾数
    
FloatDiv_CheckOverflow:
    # 检查指数上溢
    li   $t9, 254                  # 设置指数的最大值（254）
    bgt  $t1, $t9, Overflow         # 如果指数大于254，则上溢
    j    FloatDiv_ComputeMantissa   # 指数未上溢，计算尾数
    
FloatDiv_CheckUnderflow:
    # 检查指数下溢
    li   $t9, 0                    # 设置指数的最小值（0）
    blt  $t1, $t9, Underflow        # 如果指数小于0，则下溢
    j    FloatDiv_ComputeMantissa   # 指数未下溢，计算尾数
    
FloatDiv_ComputeMantissa:
    # 计算结果的尾数位：两个尾数相除
    # 在MIPS中，div指令会将两个32位整数相除，商存在LO寄存器中，余数存在HI寄存器中
    # 注意：当两个尾数比23位相除时，结果有可能小于1（都是1.xxx格式）
    # 所以需要先将被除数左移一定位数，以确保商是规格化的
    # 这里采用简化的处理方式，直接计算
    div  $s2, $s5                   # 尾数相除
    mflo $t2                       # 获取商
    
    # 检查商是否规格化（是否在范围0.5~1.0之间）
FloatDiv_NormalizeLoop:
    # 规格化：确保bit23=1
    andi $t9, $t2, 0x800000        # 检查尾数的隐含位是否为1
    bnez $t9, FloatDiv_BuildResult  # 如果隐含位为1，则已经规格化
    beqz $t2, PrintZero             # 如果尾数为0，则结果为0
    sll  $t2, $t2, 1                # 尾数左移1位
    addi $t1, $t1, -1               # 指数减1
    beqz $t1, Underflow             # 检查指数下溢
    j    FloatDiv_NormalizeLoop     # 继续规格化
    
FloatDiv_BuildResult:
    # 将尾数的隐含位清零并重组IEEE 754表示
    andi $t2, $t2, 0x7FFFFF         # 清除隐含位，只保留尾数的低23位
    sll  $t6, $t0, 31               # 符号位移位到最高位
    sll  $t7, $t1, 23               # 指数位移位到正确位置
    or   $t7, $t6, $t7              # 组合符号位和指数位
    or   $t7, $t7, $t2              # 组合尾数位
    j    PrintResult                # 跳转到打印结果

# -------------------- 打印结果子程序 --------------------
PrintResult:
    # 打印结果提示
    li   $v0, 4
    la   $a0, msg_result
    syscall
    
    # 打印二进制结果
    jal  PrintBinary
    
    # 打印十六进制结果
    jal  PrintHex
    
    # 返回菜单
    j    Menu

# -------------------- 打印零子程序 --------------------
PrintZero:
    # 构造+0的IEEE 754表示
    li   $t0, 0                     # 符号位为0（正数）
    li   $t1, 0                     # 指数位为0（表示零或非规格化数）
    li   $t2, 0                     # 尾数位为0
    # 组合IEEE 754表示
    sll  $t6, $t0, 31
    sll  $t7, $t1, 23
    or   $t7, $t6, $t7
    or   $t7, $t7, $t2
    # 打印结果
    j    PrintResult

# -------------------- 错误处理子程序 --------------------
Overflow:
    # 打印上溢错误消息
    li   $v0, 4
    la   $a0, msg_overflow
    syscall
    # 返回菜单
    j    Menu

Underflow:
    # 打印下溢错误消息
    li   $v0, 4
    la   $a0, msg_underflow
    syscall
    # 返回菜单
    j    Menu

DivideByZero:
    # 打印除零错误消息
    li   $v0, 4
    la   $a0, msg_divzero
    syscall
    # 返回菜单
    j    Menu

# -------------------- 打印二进制表示子程序 --------------------
PrintBinary:
    # 保存返回地址
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    # 打印二进制前缀
    li   $v0, 4
    la   $a0, msg_bin
    syscall
    
    # 从最高位开始逐位打印二进制字符
    move $t8, $t7                   # 将IEEE 754表示复制到$t8
    li   $t9, 32                    # 计数器：总共打印32位
    
PrintBinary_Loop:
    beqz $t9, PrintBinary_End        # 如果已经打印完所有位，则结束
    addi $t9, $t9, -1               # 计数器减1
    
    # 取出当前最高位
    srlv $t0, $t8, $t9              # 将$t8右移$t9位，将当前要打印的位移到最低位
    andi $t0, $t0, 1                # 只保留最低位
    
    # 将位值转换为字符'0'或'1'并打印
    addi $a0, $t0, '0'              # 将位值转换为ASCII码
    li   $v0, 11                    # syscall 11: 打印字符
    syscall
    
    j    PrintBinary_Loop            # 继续循环
    
PrintBinary_End:
    # 打印换行
    li   $v0, 4
    la   $a0, newline
    syscall
    
    # 恢复返回地址并返回
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# -------------------- 打印十六进制表示子程序 --------------------
PrintHex:
    # 保存返回地址
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    # 打印十六进制前缀
    li   $v0, 4
    la   $a0, msg_hex
    syscall
    
    # 从最高位开始按四位一组打印十六进制字符
    move $t8, $t7                   # 将IEEE 754表示复制到$t8
    li   $t9, 8                     # 计数器：总共打印更8个十六进制字符
    
PrintHex_Loop:
    beqz $t9, PrintHex_End           # 如果已经打印完所有十六进制字符，则结束
    addi $t9, $t9, -1               # 计数器减1
    
    # 计算移位量 = $t9 * 4
    sll  $t0, $t9, 2                # $t0 = $t9 * 4
    
    # 取出当前四位
    srlv $t0, $t8, $t0              # 将$t8右移$t0位
    andi $t0, $t0, 0xF              # 只保留低4位
    
    # 将四位转换为十六进制字符并打印
    la   $t1, hex_table              # 加载十六进制字符表
    add  $t1, $t1, $t0              # 计算字符在表中的位置
    lb   $a0, 0($t1)                # 加载字符
    li   $v0, 11                    # syscall 11: 打印字符
    syscall
    
    j    PrintHex_Loop               # 继续循环
    
PrintHex_End:
    # 打印换行
    li   $v0, 4
    la   $a0, newline
    syscall
    
    # 恢复返回地址并返回
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# -------------------- 退出程序 --------------------
Exit:
    # 打印退出消息
    li   $v0, 4
    la   $a0, msg_exit
    syscall
    
    # 结束程序
    li   $v0, 10                    # syscall 10: 结束程序
    syscall