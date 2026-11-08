import 'package:flutter/material.dart';

import 'core_bridge.dart';
import 'detail_screen.dart';
import 'local_store.dart';
import 'models.dart';
import 'widgets.dart';

class ProducerScreen extends StatefulWidget {
  const ProducerScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.store,
  });
  final Drama drama;
  final AppRepository repository;
  final LocalStore store;

  @override
  State<ProducerScreen> createState() => _ProducerScreenState();
}

class _ProducerScreenState extends State<ProducerScreen> {
  ProducerWorks? _works;
  bool _loading = true;
  bool _newest = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final works = await widget.repository.producerWorks(widget.drama);
      if (!mounted) return;
      setState(() {
        _works = works;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '加载出品方剧作失败：$error';
        _loading = false;
      });
    }
  }

  double _heatValue(String raw) {
    final match = RegExp(r'^([0-9.]+)\s*(亿|万)?').firstMatch(raw.trim());
    if (match == null) return 0;
    var value = double.tryParse(match.group(1)!) ?? 0;
    if (match.group(2) == '万') value *= 10000;
    if (match.group(2) == '亿') value *= 100000000;
    return value;
  }

  List<Drama> get _sorted {
    final items = [...?_works?.items];
    if (_newest) {
      items.sort((a, b) {
        final byDate = b.onlineDate.compareTo(a.onlineDate);
        if (byDate != 0) return byDate;
        return _heatValue(b.heat).compareTo(_heatValue(a.heat));
      });
    } else {
      items.sort((a, b) {
        final byHeat = _heatValue(b.heat).compareTo(_heatValue(a.heat));
        if (byHeat != 0) return byHeat;
        return b.onlineDate.compareTo(a.onlineDate);
      });
    }
    return items;
  }

  void _openDrama(Drama drama) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(
          drama: drama,
          repository: widget.repository,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final producer = _works?.producer ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(producer.isNotEmpty ? producer : '出品方')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  producer.isNotEmpty ? '出品方剧作' : '正在查找出品方',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('最新')),
                    ButtonSegment(value: false, label: Text('最热')),
                  ],
                  selected: {_newest},
                  onSelectionChanged: (values) =>
                      setState(() => _newest = values.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(colors)),
        ],
      ),
    );
  }

  Widget _body(ColorScheme colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if ((_works?.producer ?? '').isEmpty) {
      return Center(
        child: Text(
          '未找到该剧的出品方信息',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }
    final items = _sorted;
    if (items.isEmpty) {
      return Center(
        child: Text(
          '没有找到该出品方的其他剧作',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            padding,
            8,
            padding,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: dramaGridDelegate(
            context,
            constraints.maxWidth - 2 * padding,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => DramaTile(
            key: ValueKey(items[index].id),
            drama: items[index],
            repository: widget.repository,
            onTap: () => _openDrama(items[index]),
          ),
        );
      },
    );
  }
}
