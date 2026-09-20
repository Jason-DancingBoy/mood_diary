import 'dart:math';

class EmotionEntry {
  final String chinese;
  final String description;
  final double energy;
  final double pleasantness;
  final String quadrant;
  final int displayPriority;

  const EmotionEntry({
    required this.chinese,
    required this.description,
    required this.energy,
    required this.pleasantness,
    required this.quadrant,
    this.displayPriority = 0,
  });

  double distanceTo(double e, double p) {
    return sqrt(pow(energy - e, 2) + pow(pleasantness - p, 2));
  }
}

const List<EmotionEntry> emotionEntries = [
  // ========== Red Quadrant: High Energy, Unpleasant ==========
  EmotionEntry(chinese: '愤怒', description: '感觉不被尊重，心里很不舒服', energy: 0.8, pleasantness: -0.8, quadrant: 'red', displayPriority: 10),
  EmotionEntry(chinese: '暴怒', description: '怒火中烧，快要控制不住自己了', energy: 0.95, pleasantness: -0.9, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '恼火', description: '遇到不顺心的事，心里很不痛快', energy: 0.6, pleasantness: -0.5, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '烦躁', description: '做什么都静不下心来', energy: 0.5, pleasantness: -0.4, quadrant: 'red', displayPriority: 9),
  EmotionEntry(chinese: '焦虑', description: '心里七上八下的，总担心有什么事', energy: 0.7, pleasantness: -0.7, quadrant: 'red', displayPriority: 10),
  EmotionEntry(chinese: '紧张', description: '浑身紧绷绷的，怎么也放松不下来', energy: 0.6, pleasantness: -0.5, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '恐慌', description: '突然慌了神，不知道该怎么办才好', energy: 0.9, pleasantness: -0.8, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '恐惧', description: '害怕得要命，只想赶快逃离这里', energy: 0.8, pleasantness: -0.9, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '害怕', description: '心里直打鼓，总觉得要出什么事', energy: 0.7, pleasantness: -0.8, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '惊吓', description: '被吓得猛地一激灵，心都跳到嗓子眼了', energy: 0.95, pleasantness: -0.85, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '惊慌', description: '手忙脚乱的，完全不知道先做什么好', energy: 0.9, pleasantness: -0.75, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '嫉妒', description: '看到别人好，心里酸溜溜的不是滋味', energy: 0.5, pleasantness: -0.6, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '憎恨', description: '恨得牙痒痒，一想到就来气', energy: 0.8, pleasantness: -0.9, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '不公平', description: '凭什么这样对我，太不公平了', energy: 0.6, pleasantness: -0.7, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '压力', description: '压得喘不过气来，肩膀好沉', energy: 0.6, pleasantness: -0.4, quadrant: 'red', displayPriority: 9),
  EmotionEntry(chinese: '崩溃', description: '真的撑不住了，整个人都要垮掉了', energy: 0.7, pleasantness: -0.95, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '抗拒', description: '心里很抵触，一点都不想接受', energy: 0.3, pleasantness: -0.5, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '反感', description: '打心底里讨厌，多看一眼都不愿意', energy: 0.4, pleasantness: -0.7, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '不满', description: '心里不太痛快，觉得这样不够好', energy: 0.3, pleasantness: -0.4, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '恼怒', description: '越想越气，火气蹭蹭往上冒', energy: 0.7, pleasantness: -0.6, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '激动(负面)', description: '坐也不是站也不是，心里乱糟糟的', energy: 0.8, pleasantness: -0.5, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '冲动', description: '一股热血冲上头，怎么也压不住', energy: 0.7, pleasantness: -0.3, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '受挫', description: '努力了半天却碰了一鼻子灰，好泄气', energy: 0.4, pleasantness: -0.6, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '被冒犯', description: '感觉不被尊重，心里很不舒服', energy: 0.6, pleasantness: -0.7, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '愤慨', description: '看到不公的事，胸中涌起一股义愤', energy: 0.75, pleasantness: -0.75, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '敌意', description: '看对方不顺眼，总想跟他对着干', energy: 0.7, pleasantness: -0.8, quadrant: 'red', displayPriority: 3),
  EmotionEntry(chinese: '抓狂', description: '被逼得快发疯，整个人都要炸了', energy: 0.85, pleasantness: -0.6, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '坐立不安', description: '心里有事搁着，怎么都安顿不下来', energy: 0.55, pleasantness: -0.45, quadrant: 'red', displayPriority: 5),

  // ========== Yellow Quadrant: High Energy, Pleasant ==========
  EmotionEntry(chinese: '快乐', description: '心里像吃了蜜一样甜', energy: 0.7, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 10),
  EmotionEntry(chinese: '兴奋', description: '心跳得很快，整个人都兴奋起来了', energy: 0.9, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 9),
  EmotionEntry(chinese: '激动', description: '热血涌上心头，激动得不行', energy: 0.85, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '狂喜', description: '开心得不得了，嘴巴合都合不上', energy: 0.95, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '幸福', description: '心里被温暖填得满满的', energy: 0.5, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 10),
  EmotionEntry(chinese: '欢喜', description: '打心底里高兴，眉梢眼角都是笑意', energy: 0.6, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '自豪', description: '我做到了，心里满满都是成就感', energy: 0.6, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '骄傲', description: '觉得自己真了不起，心里得意极了', energy: 0.5, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '乐观', description: '凡事往好处想，相信一切都会好起来的', energy: 0.4, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '希望', description: '觉得前方有光，日子有奔头', energy: 0.3, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '渴望', description: '心里痒痒的，恨不得马上就能得到', energy: 0.7, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '期待', description: '伸长了脖子盼着，心里充满期待', energy: 0.5, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '热爱', description: '打心底里喜欢，想到就觉得很美好', energy: 0.7, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '惊喜', description: '完全没想到，又惊又喜的感觉', energy: 0.8, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '精力充沛', description: '浑身有使不完的劲，感觉自己无所不能', energy: 0.8, pleasantness: 0.4, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '活跃', description: '整个人活力满满，坐都坐不住', energy: 0.6, pleasantness: 0.4, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '开心', description: '心情美美的，看什么都顺眼', energy: 0.5, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 9),
  EmotionEntry(chinese: '欢快', description: '脚步轻飘飘的，心里哼着小曲', energy: 0.7, pleasantness: 0.75, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '满足', description: '对现在拥有的很满足，心里踏实又安稳', energy: 0.3, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '热情', description: '浑身充满干劲，迫不及待想大干一场', energy: 0.75, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '兴高采烈', description: '高兴得要飞起来了，见谁都想笑', energy: 0.85, pleasantness: 0.85, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '得意', description: '心里美滋滋的，忍不住暗暗高兴', energy: 0.5, pleasantness: 0.65, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '感激', description: '心里满是感激，不知道该怎么感谢才好', energy: 0.2, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '有动力', description: '浑身都是劲，动力满满地往前冲', energy: 0.6, pleasantness: 0.55, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '受鼓舞', description: '被狠狠地激励到了，心里燃起一团火', energy: 0.55, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '雀跃', description: '开心得想蹦蹦跳跳，像只快乐的小鸟', energy: 0.8, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '兴致勃勃', description: '兴趣上来了，恨不得马上动手试试', energy: 0.65, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 5),

  // ========== Blue Quadrant: Low Energy, Unpleasant ==========
  EmotionEntry(chinese: '悲伤', description: '心里堵得慌，眼泪在眼眶里打转', energy: -0.6, pleasantness: -0.7, quadrant: 'blue', displayPriority: 10),
  EmotionEntry(chinese: '伤心', description: '心像被针扎了一样，一阵一阵地疼', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 9),
  EmotionEntry(chinese: '忧郁', description: '心里疙疙瘩瘩的，怎么也高兴不起来', energy: -0.6, pleasantness: -0.5, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '抑郁', description: '眼前灰蒙蒙一片，看不到一点色彩', energy: -0.7, pleasantness: -0.8, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '沮丧', description: '像泄了气的皮球，打不起精神', energy: -0.4, pleasantness: -0.6, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '失落', description: '心里空落落的，像少了什么东西', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '失望', description: '满心期待却落了空，心里凉了半截', energy: -0.3, pleasantness: -0.6, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '绝望', description: '一点希望都看不到，彻底心凉了', energy: -0.8, pleasantness: -0.9, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '无助', description: '觉得没有人可以帮到自己', energy: -0.7, pleasantness: -0.7, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '无力', description: '浑身软绵绵的，什么事都不想干', energy: -0.8, pleasantness: -0.5, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '孤独', description: '感觉自己孤零零的，没有人懂自己', energy: -0.6, pleasantness: -0.6, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '寂寞', description: '周围冷冷清清的，心里也空空的', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '思念', description: '想一个人想到心里发酸', energy: -0.3, pleasantness: -0.2, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '内疚', description: '心里过意不去，觉得都是自己的错', energy: -0.4, pleasantness: -0.6, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '羞愧', description: '尴尬得恨不得找个地缝钻进去', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '懊悔', description: '早知道会这样就不做了，后悔得要命', energy: -0.4, pleasantness: -0.5, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '后悔', description: '真不该那么做，越想越后悔', energy: -0.4, pleasantness: -0.55, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '厌倦', description: '厌烦透了，连搭理都不想搭理', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '疲惫', description: '累得骨头都要散架了，只想瘫着不动', energy: -0.7, pleasantness: -0.3, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '疲倦', description: '困得眼皮直打架，脑子都转不动了', energy: -0.8, pleasantness: -0.2, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '无聊', description: '做什么都没意思，时间过得好慢', energy: -0.4, pleasantness: -0.3, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '冷漠', description: '什么都不在乎，懒得关心任何人任何事', energy: -0.7, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '麻木', description: '整个人木木的，开心难过都没什么感觉', energy: -0.7, pleasantness: -0.4, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '空虚', description: '心里空荡荡的，感觉做什么都没意义', energy: -0.5, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '消沉', description: '提不起精神来，整个人蔫蔫的', energy: -0.6, pleasantness: -0.55, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '自卑', description: '觉得自己哪里都不够好，比不上别人', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '委屈', description: '明明不是我的错，却要被这样对待', energy: -0.3, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '心碎', description: '心像被人狠狠摔碎了，疼得无法呼吸', energy: -0.6, pleasantness: -0.85, quadrant: 'blue', displayPriority: 5),

  // ========== Green Quadrant: Low Energy, Pleasant ==========
  EmotionEntry(chinese: '平静', description: '内心很平静，没什么波澜', energy: -0.5, pleasantness: 0.5, quadrant: 'green', displayPriority: 10),
  EmotionEntry(chinese: '安宁', description: '内心安安稳稳的，什么都打扰不了我', energy: -0.6, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '宁静', description: '四周安安静静，心里也一片澄澈', energy: -0.7, pleasantness: 0.5, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '平和', description: '心里不急不躁，一切刚刚好', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '从容', description: '不慌不忙的，一步一步按自己的节奏来', energy: -0.3, pleasantness: 0.4, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '淡定', description: '遇到什么事都能稳住，心里不慌', energy: -0.5, pleasantness: 0.3, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '放松', description: '终于可以松一口气了，整个人都软下来', energy: -0.4, pleasantness: 0.5, quadrant: 'green', displayPriority: 9),
  EmotionEntry(chinese: '舒缓', description: '不着急，慢慢来，一切都来得及', energy: -0.6, pleasantness: 0.4, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '舒适', description: '一切都刚刚好，多一分少一分都不如现在', energy: -0.3, pleasantness: 0.7, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '惬意', description: '舒舒服服地待着，什么都不用想', energy: -0.2, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '自在', description: '想干嘛就干嘛，无拘无束的感觉真好', energy: -0.2, pleasantness: 0.6, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '悠闲', description: '时间很充裕，不慌不忙地做自己的事', energy: -0.5, pleasantness: 0.7, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '满足', description: '有这样就已经很好了，心里很知足', energy: -0.3, pleasantness: 0.8, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '感恩', description: '心里充满感激，谢谢你在我身边', energy: -0.2, pleasantness: 0.7, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '感动', description: '被深深触动了，心里暖暖的酸酸的', energy: 0.0, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '温馨', description: '心里荡漾着一股暖意，特别舒服', energy: -0.3, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '温暖', description: '有人惦记着关心着，心里暖暖的', energy: -0.1, pleasantness: 0.7, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '安心', description: '心里的一块石头落地了，终于可以安心了', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '安全', description: '有人护着，感觉很安心很踏实', energy: -0.5, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '信任', description: '从心底里信任对方，不需要任何怀疑', energy: -0.3, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '尊重', description: '感觉自己被认真对待，受到了尊重', energy: -0.2, pleasantness: 0.4, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '欣赏', description: '打心底里欣赏，觉得这个人真好', energy: -0.1, pleasantness: 0.6, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '敬佩', description: '发自内心地佩服，觉得对方真的很了不起', energy: 0.0, pleasantness: 0.7, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '敬畏', description: '既尊敬又带着一点敬畏，不敢造次', energy: -0.2, pleasantness: 0.5, quadrant: 'green', displayPriority: 4),
  EmotionEntry(chinese: '同情', description: '能感受到对方的难处，心里也跟着难受', energy: -0.5, pleasantness: 0.3, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '满足感', description: '心里满满当当的，没什么可遗憾的了', energy: -0.3, pleasantness: 0.7, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '释然', description: '终于放下了，心里轻松了许多', energy: -0.4, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '踏实', description: '心里踏踏实实的，觉得一切都很稳', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '充实', description: '过得充实又有意义，心里满满当当的', energy: -0.2, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
];

EmotionEntry findNearestEmotion(double energy, double pleasantness) {
  EmotionEntry nearest = emotionEntries.first;
  double minDist = nearest.distanceTo(energy, pleasantness);
  for (final entry in emotionEntries) {
    final dist = entry.distanceTo(energy, pleasantness);
    if (dist < minDist) {
      minDist = dist;
      nearest = entry;
    }
  }
  return nearest;
}

List<EmotionEntry> getEmotionsByQuadrant(String quadrant) {
  return emotionEntries.where((e) => e.quadrant == quadrant).toList();
}

List<EmotionEntry> getDisplayEmotions({int limit = 30}) {
  final sorted = List<EmotionEntry>.from(emotionEntries)
    ..sort((a, b) => b.displayPriority.compareTo(a.displayPriority));
  return sorted.take(limit).toList();
}

List<EmotionEntry> getNearbyEmotions(double energy, double pleasantness, {int count = 6}) {
  final sorted = List<EmotionEntry>.from(emotionEntries)
    ..sort((a, b) => a.distanceTo(energy, pleasantness).compareTo(b.distanceTo(energy, pleasantness)));
  return sorted.take(count).toList();
}
