class TopicLibrary {
  static const themes = <ThemePlan>[
    ThemePlan(
      title: '深海科考：马里亚纳',
      rootChats: [
        RootChatPlan(
          title: '下潜记录：万米海沟',
          child: BranchPlan(
            title: '声呐异常信号分析',
            prompt: '在 10900 米处捕获到非自然节律的低频声呐信号，请分析可能的来源。',
            expectedReply: '信号分析显示：周期性波形排除地质活动；怀疑为大型头足类生物或未记录的深海热液脉冲。建议调整水听器增益。',
            child: BranchPlan(
              title: '生物发光现象观察',
              prompt: '潜水器外窗观测到淡蓝色阵发性闪烁，伴随声呐信号增强。请对比生物库。',
              expectedReply: '对比结果：发光频率与已知大王乌贼亚种不符；推测为新型极端环境掠食者。已记录光谱数据。',
            ),
          ),
        ),
        RootChatPlan(
          title: '热液喷口采样',
          child: BranchPlan(
            title: '矿物成分实时分析',
            prompt: '机械臂抓取黑烟囱喷口附近的结晶样本，初步光谱分析结果异常，请评估价值。',
            expectedReply: '样本富含稀有稀土元素及高纯度硫化镍。这证明了该区域具有极高的地质研究与潜在工业价值。',
            child: BranchPlan(
              title: '嗜极生物培养建议',
              prompt: '样本中发现活体微生物。在升温加压仓中，应设置怎样的初始环境参数？',
              expectedReply: '建议参数：压力 100MPa，温度 120°C，硫化氢浓度 5%。避免环境骤降导致细胞壁塌陷。',
            ),
          ),
        ),
        RootChatPlan(
          title: '海床 3D 测绘',
          child: BranchPlan(
            title: '裂缝扩张速率推演',
            prompt: '对比三年前的声呐云图，发现 4 号断裂带向东北扩张了 12 厘米，推算地壳应力。',
            expectedReply: '扩张速率异常。推算应力集中于板块交界处，未来半年内该海域发生 6 级以上地震的概率提升 15%。',
            child: BranchPlan(
              title: '自动导航航线优化',
              prompt: '由于断裂带扩张，原定自动航行路径存在碰撞风险。请重新规划。',
              expectedReply: '航线已重规划：避开 4 号断裂带中心，沿东侧海岭脊线行驶。能耗预计增加 4%，安全性提升 100%。',
            ),
          ),
        ),
      ],
      noteSeed: NoteSeed(
        title: '深海任务简报',
        body: '马里亚纳海沟探测关键点：\n- 万米级声呐异常（疑似新型生物）\n- 黑烟囱喷口高价值矿物发现\n- 断裂带地壳应力预警',
      ),
    ),
    ThemePlan(
      title: '火星殖民：阿瑞斯一号',
      rootChats: [
        RootChatPlan(
          title: '温室能量循环',
          child: BranchPlan(
            title: '氧气产出波动排查',
            prompt: '3 号温室昨夜氧气产量下降 12%，二氧化碳水平上升，请分析作物健康或设备故障。',
            expectedReply: '传感器显示光照系统功率波动。推测为尘暴导致的太阳能板遮蔽，已自动启用应急核能备用电源。',
            child: BranchPlan(
              title: '自动收割逻辑调整',
              prompt: '由于氧气波动影响了土豆生长周期，建议延迟收割并调整营养液比例。',
              expectedReply: '收割计划延后 48 小时。营养液氮磷钾比例已调整为 10:15:12，以增强植株抗逆性。',
            ),
          ),
        ),
        RootChatPlan(
          title: '水循环系统监测',
          child: BranchPlan(
            title: '地下冰川融化效率',
            prompt: '微波加热器在 A-12 区的融冰速度慢于预期，请根据地层硬度优化参数。',
            expectedReply: '地层含有高浓度玄武岩，导致微波损耗。建议切换为激光热熔钻头，并增加 15% 的输入功率。',
            child: BranchPlan(
              title: '水质二次净化标准',
              prompt: '融化后的水中检测出超标高氯酸盐，现有反渗透系统是否足以处理？',
              expectedReply: '现有系统负荷过重。建议增加电化学降解前处理环节，以确保饮用水安全标准。',
            ),
          ),
        ),
        RootChatPlan(
          title: '基地结构完整性',
          child: BranchPlan(
            title: '微陨石撞击评估',
            prompt: '雷达监测到 B 区圆顶发生微弱振动，疑似微陨石撞击，请调取外部监控。',
            expectedReply: '确认撞击：0.5mm 坑洞，未穿透复合装甲层。结构完整性 99.8%，建议派无人机进行表面修补。',
            child: BranchPlan(
              title: '充气模组压力补偿',
              prompt: '为了防止撞击点疲劳，是否需要调整 B 区内部气压以降低张力？',
              expectedReply: '不建议降低。维持现有气压有助于内支撑结构稳定。只需在修补完成后进行局部加固即可。',
            ),
          ),
        ),
      ],
      noteSeed: NoteSeed(
        title: '火星基地运行日志',
        body: '阿瑞斯一号运行状态：\n- 3 号温室氧气平衡修复\n- A-12 区水资源开采进度 65%\n- 基地结构完整性良好，已完成 B 区修补',
      ),
    ),
    ThemePlan(
      title: '智网核心：赛博安全',
      rootChats: [
        RootChatPlan(
          title: '防火墙入侵溯源',
          child: BranchPlan(
            title: '异常流量模式识别',
            prompt: '外网网关发现大量随机端口的 SYN 请求，伴随高度混淆的加密特征，请溯源。',
            expectedReply: '识别为分布式拒绝服务攻击（DDoS）前兆。攻击源通过全球 500+ 跳板机伪装，特征指向“幻影”黑客组织。',
            child: BranchPlan(
              title: '蜜罐系统部署建议',
              prompt: '为了捕获攻击者的真实指纹，应在哪个子网部署蜜罐？',
              expectedReply: '建议在 DMZ 隔离区部署伪造的核心数据库镜像。利用高诱导性配置诱使攻击者执行深度指令。',
            ),
          ),
        ),
        RootChatPlan(
          title: '加密资产防护',
          child: BranchPlan(
            title: '私钥存储冷热隔离',
            prompt: '针对近期频发的内存溢出攻击，请重新设计冷热资产比例及签名授权流程。',
            expectedReply: '建议：95% 资产入冷库；热钱包仅保留 5%。多签授权需引入硬件令牌及生物识别双重验证。',
            child: BranchPlan(
              title: '零知识证明集成',
              prompt: '在审计流程中引入 ZKP 是否能降低隐私泄露风险？请给出方案。',
              expectedReply: '集成 ZKP 可实现“在不暴露交易细节的情况下证明合法性”。方案：部署零知识验证节点，覆盖所有大额划转。',
            ),
          ),
        ),
        RootChatPlan(
          title: '系统自愈策略',
          child: BranchPlan(
            title: '容器镜像自动回滚',
            prompt: '生产环境 A 组容器检测到未知恶意代码修改了二进制文件，请触发自愈。',
            expectedReply: '已拦截写请求并隔离容器。正从只读仓库自动拉取“黄金镜像”进行覆盖回滚。',
            child: BranchPlan(
              title: '漏洞自动补丁流程',
              prompt: '回滚后如何确保该漏洞不会再次被利用？是否需要自动生成补丁？',
              expectedReply: '正扫描二进制差异。已发现缓冲区溢出点，自动生成内存加固策略并同步至所有节点。',
            ),
          ),
        ),
      ],
      noteSeed: NoteSeed(
        title: '安全中心审计报告',
        body: '赛博安全风险总结：\n- “幻影”组织 DDoS 攻击已拦截\n- 资产冷热隔离升级完成\n- 容器自愈系统验证通过',
      ),
    ),
  ];
}

class ThemePlan {
  const ThemePlan({
    required this.title,
    required this.rootChats,
    required this.noteSeed,
  });

  final String title;
  final List<RootChatPlan> rootChats;
  final NoteSeed noteSeed;
}

class RootChatPlan {
  const RootChatPlan({
    required this.title,
    this.child,
  });

  final String title;
  final BranchPlan? child;
}

class BranchPlan {
  const BranchPlan({
    required this.title,
    required this.prompt,
    required this.expectedReply,
    this.child,
  });

  final String title;
  final String prompt;
  final String expectedReply;
  final BranchPlan? child;
}

class NoteSeed {
  const NoteSeed({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}


