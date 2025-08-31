#!/bin/bash

echo "🔍 验证 TollFund iOS 项目..."
echo "=================================="

# 检查项目文件
echo "📁 检查项目结构:"
if [ -f "TollFund.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode项目文件存在"
else
    echo "❌ Xcode项目文件缺失"
    exit 1
fi

# 检查Swift文件
echo "🔧 检查Swift源文件:"
required_files=(
    "TollFund/TollFundApp.swift"
    "TollFund/ContentView.swift"
    "TollFund/Models/DataModel.swift"
    "TollFund/Managers/DataManager.swift"
    "TollFund/Views/DashboardView.swift"
    "TollFund/Views/DailyTasksView.swift"
    "TollFund/Views/BigTasksView.swift"
    "TollFund/Views/ExpensesView.swift"
    "TollFund/Views/StatisticsView.swift"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file 缺失"
    fi
done

# 检查Core Data文件
echo "💾 检查Core Data文件:"
if [ -f "TollFund/TollFund.xcdatamodeld/TollFund.xcdatamodel/contents" ]; then
    echo "✅ Core Data模型文件存在"
else
    echo "❌ Core Data模型文件缺失"
fi

# 检查Assets
echo "🎨 检查Assets文件:"
if [ -d "TollFund/Assets.xcassets" ]; then
    echo "✅ Assets.xcassets目录存在"
else
    echo "❌ Assets.xcassets目录缺失"
fi

# 统计代码行数
echo "📊 项目统计:"
swift_lines=$(find TollFund -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
echo "📝 Swift代码总行数: $swift_lines"

swift_files=$(find TollFund -name "*.swift" | wc -l)
echo "📄 Swift文件数量: $swift_files"

echo "=================================="
echo "🎉 项目验证完成！"
echo ""
echo "📱 使用说明:"
echo "1. 在Xcode中打开 TollFund.xcodeproj"
echo "2. 选择iOS模拟器或真机"
echo "3. 点击运行按钮 (Cmd+R)"
echo "4. 开始使用奖励追踪应用！"
echo ""
echo "🚀 主要功能:"
echo "- 📋 每日任务管理和奖励"
echo "- 🎯 大任务项目追踪"
echo "- 💳 消费记录管理"
echo "- 📊 统计分析和图表"
echo "- 🏠 资金余额概览"


