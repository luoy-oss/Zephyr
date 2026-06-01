/// 音符模型 - 对应光遇琴键上的一个音
class Note {
  /// 显示名称 (如 "1", "-1", "+1")
  final String name;

  /// 在网格中的行 (0-2)
  final int row;

  /// 在网格中的列 (0-4)
  final int col;

  const Note({
    required this.name,
    required this.row,
    required this.col,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// 光遇钢琴的15个音符定义
class SkyNotes {
  static const List<Note> all = [
    // 第0行：低音区
    Note(name: '-1', row: 0, col: 0),
    Note(name: '-2', row: 0, col: 1),
    Note(name: '-3', row: 0, col: 2),
    Note(name: '-4', row: 0, col: 3),
    Note(name: '-5', row: 0, col: 4),
    // 第1行：中音区
    Note(name: '-6', row: 1, col: 0),
    Note(name: '-7', row: 1, col: 1),
    Note(name: '1', row: 1, col: 2),
    Note(name: '2', row: 1, col: 3),
    Note(name: '3', row: 1, col: 4),
    // 第2行：高音区
    Note(name: '4', row: 2, col: 0),
    Note(name: '5', row: 2, col: 1),
    Note(name: '6', row: 2, col: 2),
    Note(name: '7', row: 2, col: 3),
    Note(name: '+1', row: 2, col: 4),
  ];

  /// 根据名称查找音符
  static Note? findByName(String name) {
    try {
      return all.firstWhere((n) => n.name == name);
    } catch (_) {
      return null;
    }
  }
}
