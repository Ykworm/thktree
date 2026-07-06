import 'package:thk_tree/ui/core/shared/markdown_rehydrate.dart';

void main() {
  print('=== Case 1: 真实病句（来自 F-disk-body-SAMPLE）===');
  final sickBody =
      '好，不要表格。重说一遍。---你的核心特点**第一，审美洁癖 +实用主义。**你不是那种"喜欢好看的东西"的人，你是"容忍不了丑的和臃肿的东西"。MFC丑，你就用 Qt。C#继承太复杂，你就觉得 Python透明才舒服。go-zero臃肿，你转头就用 Gin自由组合。jQuery你觉得难玩，直接上 Angular。自己画不出图，就找 AI画，再找产品朋友帮你看美不美。关键点在：你的审美不是装饰性的，是工具性的。你觉得美的东西，恰好也是好用的东西。这不是巧合，是你对"什么是好的"有一种直觉级别的判断。**第二，嗅觉超前，但落地总是差一口气。**2013年，别人还在 jQuery和 MySQL一把梭，你已经用 Angular写前端、推 Go做性能补充、引入列式数据库了。2019年，很多团队还在手动部署，你已经独立推 K8s落地和自动化部署了。现在2024年，别人还在卷源码分析，你已经';
  print(rehydrateMarkdown(sickBody));

  print('\n\n=== Case 2: 已有 \\n 的不动 ===');
  print(rehydrateMarkdown('正常文本\n## 标题\n内容'));

  print('\n\n=== Case 3: em-dash 不误伤 ===');
  print(rehydrateMarkdown('a---b---c 都不该重建'));

  print('\n\n=== Case 4: 纯文本不动 ===');
  print(rehydrateMarkdown('你好世界。今天天气不错。'));

  print('\n\n=== Case 5: 数字列表 ===');
  print(rehydrateMarkdown('这是介绍。1. 第一项。2. 第二项。3. 第三项。'));

  print('\n\n=== Case 6: 破折号列表 ===');
  print(rehydrateMarkdown('看下面。- 苹果- 香蕉- 梨子'));

  print('\n\n=== Case 7: 混合 ===');
  print(rehydrateMarkdown('开头段。## 章节一这是内容。## 章节二那是内容。---结尾'));

  print('\n\n=== Case 8: 代码围栏 ===');
  print(rehydrateMarkdown('看代码：```dart\nvoid main() {}\n```'));

  print('\n\n=== Case 9: 真实 DeepSeek 病句（标记全黏在一起，user 截图 case）===');
  final sickBody2 =
      '你负说得对，#后面必须跟一个空格才是标准的markdown标题语法。抱歉，我之前的写法不规范。以下是修正后的版本，所有标题、列表、分割线都按标准格式处理:---#你的特点##1.审美洁癖 +实用主义，两者绑定在一起你不是单纯"喜欢好看的东西"。你是容忍不了綈梓х噙的东西，而且丑的东西你恰好也用不顺手。-MFC丑 →你用 Qt- C#继承太复杂你觉得 Python透明所以喜欢-go-zero臃肿>Gin能自由组合所以你用 Gin-iQuery难玩>你直接上 Angular-自己画不出图 →找 A和产品朋友帮你验证美不美关键点:你的审美不是装饰性的，是工具性的。你觉得美的东西恰好也是用起来最舒服的东西。这两个判断在你这里是同一条神经。---##2.嗅觉超前，但落地总差一口气-2013年你就推 Go、用Angular、引入列式数据库--当时主流是Java/.NET、jQuery、MySQL一把梭。-2019年你独立推 K8s落地和自动化部署，当';
  print(rehydrateMarkdown(sickBody2));

  print('\n\n=== Case 10: ## 后直接接数字（无空格）===');
  print(rehydrateMarkdown('结尾段。##1. 第一节内容##2. 第二节内容'));

  print('\n\n=== Case 11: - 后直接接内容（无空格）===');
  print(rehydrateMarkdown('结尾段。-MFC丑- C#难-Qt好用'));

  print('\n\n=== Case 12: 中文字前面接 ## 标题 ===');
  print(rehydrateMarkdown('段尾##1.审美##2.结构'));

  print('\n\n=== Case 13: em-dash -- 不被 - 规则误伤 ===');
  print(rehydrateMarkdown('这是一句话 -- 中间有 em-dash 隔开。'));

  print('\n\n=== Case 14: Qt- C# 字母尾 + dash + 空格 + 大写 → 切为列表项 ===');
  print(rehydrateMarkdown('我用 Qt- C#继承，觉得 Go比 Java透明。'));

  print('\n\n=== Case 15: --- 后面紧跟 ## ===');
  print(rehydrateMarkdown('前导文本。---##2.新章节##3.另一章'));

  print('\n\n=== Case 16 (user #1): #你的特点 前面是中文 ===');
  print(rehydrateMarkdown('段尾#你的特点##1.审美洁癖 +实用主义'));

  print('\n\n=== Case 17 (user #2): 标题 # 前是全角逗号 ，===');
  print(rehydrateMarkdown('前面有逗号，#标题1##标题2'));

  print('\n\n=== Case 18 (user #4): - 用 Lovable 无空格 ===');
  print(rehydrateMarkdown('你差点通宵的时候：-用 Lovable做 logo-用 vibe coding做 APP你从来没这样过。'));

  print('\n\n=== Case 19 (user #5): -2012年 无空格列表项 ===');
  print(rehydrateMarkdown('差一口气-2012年面试你说 Python透明 C#复杂-2013年你就推 Go'));

  print('\n\n=== Case 20: 排除 # 避免误伤 ##1. 内的 1. ===');
  print(rehydrateMarkdown('段尾##1.审美##2.结构'));

  print('\n\n=== Case 21: 1.0 小数不应被切 ===');
  print(rehydrateMarkdown('圆周率3.14左右，你刚才说 1.0 是起点。'));

  print('\n\n=== Case 22: C# / F# / a#b 不被切 ===');
  print(rehydrateMarkdown('我用 C# 写后端，F# 处理数据，a#b 是占位符。'));

  print('\n\n=== Case 23: 中文括号前接 # ===');
  print(rehydrateMarkdown('看上面（#重点1）和（#重点2）这两个标记。'));

  print('\n\n=== Case 24: em-dash —— 不被切 ===');
  print(rehydrateMarkdown('激怒了——你不是不在乎，你是期待被理解。'));

  print('\n\n=== Case 25 (user): # 后面补空格 (#你的特点 → # 你的特点) ===');
  print(rehydrateMarkdown('段尾#你的特点##1.审美洁癖 ##2.结构 ###三级标题'));

  print('\n\n=== Case 26: # 后面有空格不重复补 ===');
  print(rehydrateMarkdown('段尾# 已有空格 ## 也有空格'));

  print('\n\n=== Case 27: # 后面直接接 #（## 链式） ===');
  print(rehydrateMarkdown('段尾##1.审美###1.1子节####最深'));

  print('\n\n=== Case 28 (user): 字符串以 # 开头 → #h1+长bold+---+#h2 ===');
  print(rehydrateMarkdown(
      '#一句话总结**你是一个品味驱动、反馈敏感、嗅觉超前、需要被懂的人认可的创作者型技术人。但你十几年一直困在一个"工程师必须会写底层、会造轮子"的旧评价体系里，用别人的尺子量自己，越量越觉得自己没路。**---#按这个特点'));

  print('\n\n=== Case 29 (user): h1 后直接接 ##h2，无空格无换行 ===');
  print(rehydrateMarkdown('#按这个特点，什么工作适合你##最匹配：小团队'));

  print('\n\n=== Case 30: ### 三级标题无空格 ===');
  print(rehydrateMarkdown('前面的话###三级标题内容继续'));

  print('\n\n=== Case 31: **bold 结束后紧跟 --- HR ===');
  print(rehydrateMarkdown('正文结束**加粗总结。**---下一部分'));

  print('\n\n=== Case 32: 字符串以 --- 开头 ===');
  print(rehydrateMarkdown('---分割线前无内容---后面继续'));

  print('\n\n=== Case 33: 字符串以 1. 开头（数字列表项在开头） ===');
  print(rehydrateMarkdown('1.第一项2.第二项3.第三项'));

  print('\n\n=== Case 34: 字符串以 - 开头（破折号列表项在开头） ===');
  print(rehydrateMarkdown('-苹果-香蕉-梨子'));

  print('\n\n=== Case 35: 长 **bold 段落紧跟中文正文（inline 短bold 不切） ===');
  print(rehydrateMarkdown('这里有**重要**提示需要注意。**这是一个很长的加粗段落因为它包含了句末标点。**后面继续正常文本。'));

  print('✅ 全部测试完成');
}
