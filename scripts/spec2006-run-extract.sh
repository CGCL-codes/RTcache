#!/bin/bash

# 检查输入参数
if [ $# -ne 1 ]; then
  echo "Usage: $0 <spec2006_directory>"
  exit 1
fi

spec_dir=$1

# 定义输出文件
output_file="spec_commands.sh"

# 开始生成输出文件
echo "# 定义 SPEC2006 测试命令" > "$output_file"
echo "declare -A spec_commands" >> "$output_file"

# 遍历 SPEC2006 文件夹下的子文件夹
for test_dir in "$spec_dir"/*; do
  if [ -d "$test_dir" ]; then
    # 查找以 do.it.sh 结尾的文件
    for script_file in "$test_dir"/*do.it.sh; do
      if [ -f "$script_file" ]; then
        # 读取文件内容并提取以 $PIN_PREFIX 开头的行
        while IFS= read -r line; do
          # 检查行是否以 $PIN_PREFIX 开头
          if [[ $line == \$PIN_PREFIX* ]]; then
            # 提取命令
            command=$(echo "$line" | sed -n 's/.*\$PIN_PREFIX \(.*\)>.*$/\1/p')
            # 修改文件名
            modified_command=$(echo "$command" | sed 's/\.linux32\.ia32/\.x86_64_sse/')

            # 提取选项
            option=$(echo "$command" | sed -E 's/.*\.x86_64_sse (.*)/\1/') 
            option=${option%%>*} # 去掉第一个 '>' 及其后面的内容
            option=${option%%<*} # 去掉第一个 '<' 及其后面的内容
            option=$(echo "$option" | sed 's/^[^ ]* //')
            modified_command=$(echo "$modified_command" | sed 's/ .*//')

            # 提取 -i 选项
            input_file=$(echo "$command" | sed -n 's/.*< \(.*\)>.*$/\1/p')
            input_file=$(echo "$input_file" | xargs) # 去除前后的空格

            test_name=$(basename "$test_dir")

            # 输出结果
            if [ -n "$input_file" ] && [ -n "$option" ]; then
              echo "spec_commands[$test_name]=\"-c $modified_command -i $input_file --option=\\\"$option\\\"\"" >> "$output_file"
            elif [ -n "$input_file" ]; then
              echo "spec_commands[$test_name]=\"-c $modified_command -i $input_file\"" >> "$output_file"
            elif [ -n "$option" ]; then
              echo "spec_commands[$test_name]=\"-c $modified_command --option=\\\"$option\\\"\"" >> "$output_file"
            else
              echo "spec_commands[$test_name]=\"-c $modified_command\"" >> "$output_file"
            fi
          fi
        done < "$script_file"
      fi
    done
  fi
done

echo "生成完成，命令保存在 $output_file 中。"
