import 'dart:async';
import 'dart:ui' as ui;
import 'package:amidakuji_app/amidakuji_utils.dart';
import 'package:amidakuji_app/model/amida_lottery.dart';
import 'package:amidakuji_app/model/participant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kColumnSpacing = 60;
const double _kCanvasWidth = 1250;
const double _kCanvasHeight = 500;
const double _kCanvasTopPadding = 40;
const double _kCanvasBottomPadding = 65;
const int _kMaxHorizontalLinesPerColumn = 7;

class AmidaBody extends StatefulWidget {
  const AmidaBody({
    required this.participantList,
    required this.wininngImagePath,
    required this.allowManualLines,
    super.key,
  });

  final String wininngImagePath;
  final List<Participant> participantList;
  final bool allowManualLines;

  @override
  State<AmidaBody> createState() => _AmidaBodyState();
}

class _AmidaBodyState extends State<AmidaBody>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedWinningIndices = {};
  late List<HorizontalLine> _horizontalLines;
  late List<AmidaLottery> lotteryList;
  List<List<Offset>> _winningLinePaths = [];
  ui.Image? image;
  bool isShowButton = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  double get _paintHeight =>
      _kCanvasTopPadding + _kCanvasHeight + _kCanvasBottomPadding;

  @override
  void initState() {
    super.initState();
    _selectedWinningIndices.addAll(_defaultWinningIndices());
    _syncLotteryList();
    _horizontalLines = widget.allowManualLines
        ? []
        : _generateRandomHorizontalLines(widget.participantList.length);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final imageData = await _loadAssetImage(widget.wininngImagePath);
        if (mounted) setState(() => image = imageData);
      } catch (e) {
        debugPrint('画像アセットの読み込みに失敗しました: $e');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<int> _defaultWinningIndices() {
    if (widget.participantList.isEmpty) return const [];
    final count = widget.participantList.length > 2
        ? 2
        : widget.participantList.length;
    return List<int>.generate(count, (index) => index);
  }

  void _syncLotteryList() {
    lotteryList = List.generate(
      widget.participantList.length,
      (index) => _selectedWinningIndices.contains(index)
          ? AmidaLottery.win
          : AmidaLottery.lose,
    );
  }

  void _toggleWinning(int index) {
    if (!isShowButton) return;
    setState(() {
      if (_selectedWinningIndices.contains(index)) {
        _selectedWinningIndices.remove(index);
      } else {
        _selectedWinningIndices.add(index);
      }
      _syncLotteryList();
    });
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (!widget.allowManualLines || !isShowButton) return;
    final x = details.localPosition.dx;
    final y = details.localPosition.dy - _kCanvasTopPadding;
    if (x < 0 || x >= _kCanvasWidth || y < 0 || y > _kCanvasHeight) return;

    final columnIndex = (x / _kColumnSpacing).floor();
    if (columnIndex >= widget.participantList.length - 1) return;
    final yFactor = (y / _kCanvasHeight).clamp(0.0, 1.0);

    setState(() {
      final existingIndex = _horizontalLines.indexWhere(
        (line) =>
            line.startColomn == columnIndex &&
            (line.yPositionFactor - yFactor).abs() < 0.05,
      );
      if (existingIndex >= 0) {
        _horizontalLines.removeAt(existingIndex);
      } else {
        _horizontalLines.add(
          HorizontalLine(
            startColomn: columnIndex,
            endColumn: columnIndex + 1,
            yPositionFactor: yFactor,
          ),
        );
      }
    });
  }

  Future<ui.Image> _loadAssetImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
    return completer.future;
  }

  List<HorizontalLine> _generateRandomHorizontalLines(int columns) {
    const min = 1;
    const max = 20;
    final result = <HorizontalLine>[];
    final previous = <double>{};
    for (var column = 0; column < columns - 1; column++) {
      final values = <double>{};
      while (values.length < _kMaxHorizontalLinesPerColumn) {
        final value = randomDecimalInRangeWithStep05(min, max);
        if (!previous.contains(value)) values.add(value);
      }
      previous..clear()..addAll(values);
      result.addAll(values.map((y) => HorizontalLine(
            startColomn: column,
            endColumn: column + 1,
            yPositionFactor: y,
          )));
    }
    return result;
  }

  void _startAnimation() {
    _calculateWinningLinePaths();
    _animationController.forward();
  }

  void _calculateWinningLinePaths() {
    final paths = <List<Offset>>[];
    final winningIndices = [
      for (var i = 0; i < lotteryList.length; i++)
        if (lotteryList[i] == AmidaLottery.win) i,
    ];

    for (final winningIndex in winningIndices) {
      final path = <Offset>[];
      var currentX = winningIndex * _kColumnSpacing;
      var currentY = _kCanvasHeight;
      double? lastProcessedY;
      path.add(Offset(currentX, currentY + _kCanvasTopPadding));

      while (currentY > 0) {
        final lines = _horizontalLines.where((line) {
          final lineY = line.yPositionFactor * _kCanvasHeight;
          return lineY < currentY &&
              (lastProcessedY == null || lineY != lastProcessedY) &&
              (line.startColomn * _kColumnSpacing == currentX ||
                  line.endColumn * _kColumnSpacing == currentX);
        }).toList()
          ..sort((a, b) => (b.yPositionFactor * _kCanvasHeight)
              .compareTo(a.yPositionFactor * _kCanvasHeight));

        if (lines.isEmpty) {
          currentY = 0;
          path.add(Offset(currentX, _kCanvasTopPadding));
          continue;
        }
        final nextLine = lines.first;
        currentY = nextLine.yPositionFactor * _kCanvasHeight;
        path.add(Offset(currentX, currentY + _kCanvasTopPadding));
        currentX = nextLine.startColomn * _kColumnSpacing == currentX
            ? nextLine.endColumn * _kColumnSpacing
            : nextLine.startColomn * _kColumnSpacing;
        path.add(Offset(currentX, currentY + _kCanvasTopPadding));
        lastProcessedY = currentY;
      }
      paths.add(path);
    }
    setState(() => _winningLinePaths = paths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight + 150),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        widget.participantList.length,
                        (index) => ChoiceChip(
                          label: Text('${index + 1}'),
                          selected: _selectedWinningIndices.contains(index),
                          onSelected: (_) => _toggleWinning(index),
                          selectedColor: Colors.red.withOpacity(0.25),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8),
                      child: GestureDetector(
                        onTapUp: widget.allowManualLines && isShowButton
                            ? _handleCanvasTap
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) => CustomPaint(
                            size: Size(_kCanvasWidth, _paintHeight),
                            painter: AmidaPainter(
                              horizontalLines: _horizontalLines,
                              nameList: widget.participantList,
                              lotteryList: lotteryList,
                              winningLinePaths: _winningLinePaths,
                              image: image,
                              animationProgress: _animation.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (isShowButton)
                    ElevatedButton(
                      onPressed: () {
                        _startAnimation();
                        setState(() => isShowButton = false);
                      },
                      child: const Text('結果を発表！'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HorizontalLine {
  const HorizontalLine({
    required this.startColomn,
    required this.endColumn,
    required this.yPositionFactor,
  });
  final int startColomn;
  final int endColumn;
  final double yPositionFactor;
}

class AmidaPainter extends CustomPainter {
  AmidaPainter({
    required this.horizontalLines,
    required this.nameList,
    required this.lotteryList,
    required this.winningLinePaths,
    required this.image,
    required this.animationProgress,
  });

  final List<HorizontalLine> horizontalLines;
  final List<Participant> nameList;
  final List<AmidaLottery> lotteryList;
  final List<List<Offset>> winningLinePaths;
  final ui.Image? image;
  final double animationProgress;

  static const winningColors = [
    Colors.red, Colors.orange, Colors.blue, Colors.green, Colors.purple,
    Colors.pink, Colors.teal, Colors.amber, Colors.indigo, Colors.cyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < nameList.length; i++) {
      final x = i * _kColumnSpacing;
      final top = _kCanvasTopPadding;
      canvas.drawLine(Offset(x, top), Offset(x, top + _kCanvasHeight), paint);

      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: '${nameList[i].lastName}\n'),
            TextSpan(text: nameList[i].firstName),
          ],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));

      if (lotteryList[i] == AmidaLottery.win && image != null) {
        final width = image!.width.toDouble();
        final height = image!.height.toDouble();
        final ratio = width / height;
        const maxWidth = 50.0;
        const maxHeight = 50.0;
        final drawWidth = ratio > 1 ? maxWidth : maxHeight * ratio;
        final drawHeight = ratio > 1 ? maxWidth / ratio : maxHeight;
        canvas.drawImageRect(
          image!,
          Rect.fromLTWH(0, 0, width, height),
          Rect.fromLTWH(
            x - drawWidth / 2,
            _kCanvasTopPadding + _kCanvasHeight + 5,
            drawWidth,
            drawHeight,
          ),
          Paint(),
        );
      }
    }

    for (final line in horizontalLines) {
      final y = _kCanvasTopPadding + size.height * 0 +
          _kCanvasHeight * line.yPositionFactor;
      canvas.drawLine(
        Offset(line.startColomn * _kColumnSpacing, y),
        Offset(line.endColumn * _kColumnSpacing, y),
        paint,
      );
    }

    final pathCount = winningLinePaths.length;
    for (var pathIndex = 0; pathIndex < pathCount; pathIndex++) {
      final start = pathIndex / pathCount;
      final end = (pathIndex + 1) / pathCount;
      final progress = ((animationProgress - start) / (end - start))
          .clamp(0.0, 1.0);
      _paintPath(canvas, winningLinePaths[pathIndex], progress,
          winningColors[pathIndex % winningColors.length]);
    }
  }

  void _paintPath(Canvas canvas, List<Offset> path, double progress, Color color) {
    if (path.length < 2 || progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final scaled = progress * (path.length - 1);
    final completed = scaled.floor().clamp(0, path.length - 1);
    for (var i = 0; i < completed; i++) {
      canvas.drawLine(path[i], path[i + 1], paint);
    }
    if (completed < path.length - 1) {
      final t = scaled - completed;
      final a = path[completed];
      final b = path[completed + 1];
      canvas.drawLine(a, Offset(a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
