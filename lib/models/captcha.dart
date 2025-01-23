//https://github.com/AungYeZawDev/slider_recaptcha

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SliderController {
  late Offset? Function() create;
}

double answerX = 0;

class SliderCaptcha extends StatefulWidget {
  const SliderCaptcha({
    required this.image,
    required this.onConfirm,
    this.title = 'Slide to authenticate',
    this.titleStyle,
    this.captchaSize = 30,
    required this.colorBar,
    required this.colorCaptChar,
    this.controller,
    this.borderImager = 0,
    this.imageToBarPadding = 3,
    this.slideContainerDecoration,
    this.icon,
    Key? key,
  })  : assert(0 <= borderImager && borderImager <= 5),
        super(key: key);
  final Widget image;
  final Future<void> Function(bool value)? onConfirm;
  final String title;
  final TextStyle? titleStyle;
  final Color colorBar;
  final Color colorCaptChar;
  final double captchaSize;
  final Widget? icon;
  final Decoration? slideContainerDecoration;
  final SliderController? controller;
  final double imageToBarPadding;
  final double borderImager;

  @override
  State<SliderCaptcha> createState() => _SliderCaptchaState();
}

class _SliderCaptchaState extends State<SliderCaptcha>
    with SingleTickerProviderStateMixin {
  double heightSliderBar = 50;
  double _offsetMove = 0;
  double answerY = 0;
  bool isLock = false;
  SliderController controller = SliderController();
  SliderController unController = SliderController();
  late Animation<double> animation;
  late AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderImager),
              child: SliderCaptCha(
                image: widget.image,
                offsetX: _offsetMove,
                offsetY: answerX,
                colorCaptChar: widget.colorCaptChar,
                sliderController: unController,
              ),
            ),
          ),
          SizedBox(height: widget.imageToBarPadding),
          //slide bar
          Container(
            height: heightSliderBar,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.colorBar,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  offset: Offset(0, 0),
                  blurRadius: 2,
                  color: widget.colorBar.withOpacity(0.5),
                )
              ],
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Text(
                    widget.title,
                    style: widget.titleStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Positioned(
                  left: _offsetMove,
                  top: 0,
                  height: 50,
                  width: 50,
                  child: GestureDetector(
                    onHorizontalDragStart: (detail) =>
                        _onDragStart(context, detail),
                    onHorizontalDragUpdate: (DragUpdateDetails detail) {
                      _onDragUpdate(context, detail);
                    },
                    onHorizontalDragEnd: (DragEndDetails detail) {
                      checkAnswer();
                    },
                    //slide button
                    child: Container(
                      height: heightSliderBar,
                      width: heightSliderBar,
                      margin: const EdgeInsets.all(4),
                      decoration: widget.slideContainerDecoration ??
                          BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: widget.colorCaptChar,
                          ),
                      child: widget.icon ??
                          const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _onDragStart(BuildContext context, DragStartDetails start) {
    if (isLock) {
      return;
    }
    setState(() {
      RenderBox getBox = context.findRenderObject() as RenderBox;
      var local = getBox.globalToLocal(start.globalPosition);
      _offsetMove = local.dx - heightSliderBar / 2;
    });
  }

  _onDragUpdate(BuildContext context, DragUpdateDetails update) {
    if (isLock) {
      return;
    }
    RenderBox getBox = context.findRenderObject() as RenderBox;
    var local = getBox.globalToLocal(update.globalPosition);

    if (local.dx < 0) {
      setState(() {
        _offsetMove = 0;
      });
      return;
    }

    if (local.dx > getBox.size.width) {
      setState(() {
        _offsetMove = getBox.size.width - heightSliderBar;
      });
      return;
    }

    setState(() {
      _offsetMove = local.dx - heightSliderBar / 2;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      controller = SliderController();
    } else {
      controller = widget.controller!;
    }

    controller.create = create;

    animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    animation = Tween<double>(begin: 1, end: 0).animate(animationController)
      ..addListener(() {
        setState(() {
          _offsetMove = _offsetMove * animation.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          animationController.reset();
        }
      });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        controller.create.call();
      });
    });
    super.didChangeDependencies();
  }

  void onUpdate(double d) {
    setState(() {
      _offsetMove = d;
    });
  }

  Future<void> checkAnswer() async {
    if (isLock) {
      return;
    }
    isLock = true;

    if (_offsetMove < answerX + 10 && _offsetMove > answerX - 10) {
      await widget.onConfirm?.call(true);
    } else {
      await widget.onConfirm?.call(false);
    }
    isLock = false;
  }

  Offset? create() {
    animationController.forward().then((value) {
      setState(() {
        Offset? offset = unController.create.call();
        answerX = offset?.dx ?? 0;
        answerY = offset?.dy ?? 0;
      });
    });
    return null;
  }
}

typedef SliderCreate = Offset? Function();

class SliderCaptCha extends SingleChildRenderObjectWidget {
  final Widget image;
  final double offsetX;
  final double offsetY;
  final Color colorCaptChar;
  final double sizeCaptChar;
  final SliderController sliderController;

  const SliderCaptCha({
    required this.image,
    required this.offsetX,
    required this.offsetY,
    this.sizeCaptChar = 40,
    required this.colorCaptChar,
    required this.sliderController,
    Key? key,
  }) : super(key: key, child: image);

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = RenderTestSliderCaptChar();
    sliderController.create = renderObject.create;
    renderObject.offsetX = offsetX;
    renderObject.offsetY = offsetY;
    renderObject.colorCaptChar = colorCaptChar;
    renderObject.sizeCaptChar = sizeCaptChar;
    return renderObject;
  }

  @override
  void updateRenderObject(context, RenderTestSliderCaptChar renderObject) {
    renderObject.offsetX = offsetX;
    renderObject.offsetY = offsetY;
    renderObject.colorCaptChar = colorCaptChar;
    renderObject.sizeCaptChar = sizeCaptChar;
    super.updateRenderObject(context, renderObject);
  }
}

class RenderTestSliderCaptChar extends RenderProxyBox {
  double sizeCaptChar = 40;
  double strokeWidth = 3;
  double offsetX = 0;
  double offsetY = 0;
  double createX = 0;
  double createY = 0;
  Color? colorCaptChar;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    context.paintChild(child!, offset);
    if (!(child!.size.width > 0 && child!.size.height > 0)) {
      return;
    }

    Paint paint = Paint()
      ..color = colorCaptChar!
      ..strokeWidth = strokeWidth;

    if (createX == 0 && createY == 0) {
      return;
    }

    context.canvas.drawPath(
      getPiecePathCustom(
        size,
        strokeWidth + offset.dx + createX.toDouble(),
        offset.dy + createY.toDouble(),
        sizeCaptChar,
      ),
      paint..style = PaintingStyle.fill,
    );

    context.canvas.drawPath(
      getPiecePathCustom(
        Size(size.width - strokeWidth, size.height - strokeWidth),
        strokeWidth + offset.dx + offsetX,
        offset.dy + createY,
        sizeCaptChar,
      ),
      paint..style = PaintingStyle.stroke,
    );

    layer = context.pushClipPath(
      needsCompositing,
      Offset(-createX + offsetX + offset.dx + strokeWidth, offset.dy),
      Offset.zero & size,
      getPiecePathCustom(
        size,
        createX,
        createY.toDouble(),
        sizeCaptChar,
      ),
          (context, offset) {
        context.paintChild(child!, offset);
      },
      oldLayer: layer as ClipPathLayer?,
    );
  }

  @override
  void performLayout() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      /// tam fix
      if (createX != 0 && createY != 0) {
        return;
      }
      create();
      markNeedsPaint();
    });

    super.performLayout();
  }

  Offset? create() {
    if (size == Size.zero) {
      return null;
    }
    createX = sizeCaptChar +
        Random().nextInt((size.width - 2.5 * sizeCaptChar).toInt());
    answerX = createX;
    createY = 0.0 + Random().nextInt((size.height - sizeCaptChar).toInt());
    markNeedsPaint();
    return Offset(createX, createY);
  }
}

class PuzzlePiecePainter extends CustomPainter {
  PuzzlePiecePainter(
      this.width,
      this.height,
      this.offsetX,
      this.offsetY, {
        this.paintingStyle = PaintingStyle.stroke,
      });
  final double width;
  final double height;
  final double offsetX;
  final double offsetY;
  final PaintingStyle paintingStyle;

  @override
  Future<void> paint(Canvas canvas, Size size) async {
    final Paint paint = Paint()
      ..style = paintingStyle
      ..strokeWidth = 3.0;

    canvas.drawPath(getPiecePathCustom(size, offsetX, offsetY, width), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Path getPiecePathCustom(
    Size size, double offsetX, double offsetY, double sizePart) {
  final double bumpSize = sizePart / 4;
  Path path = Path();
  path.moveTo(offsetX, offsetY);
  path.lineTo(offsetX + sizePart / 3, offsetY);
  path.cubicTo(
    offsetX + sizePart / 6,
    offsetY + bumpSize,
    offsetX + sizePart / 6 * 5,
    offsetY + bumpSize,
    offsetX + sizePart / 3 * 2,
    offsetY,
  );
  path.lineTo(offsetX + sizePart, offsetY);
  path.lineTo(offsetX + sizePart, offsetY + sizePart / 3);
  path.cubicTo(
      offsetX + sizePart + bumpSize,
      offsetY + sizePart / 6,
      offsetX + sizePart + bumpSize,
      offsetY + sizePart / 6 * 5,
      offsetX + sizePart,
      offsetY + sizePart / 3 * 2);
  path.lineTo(offsetX + sizePart, offsetY + sizePart);
  path.lineTo(offsetX + sizePart / 3 * 2, offsetY + sizePart);
  path.lineTo(offsetX, offsetY + sizePart);
  path.lineTo(offsetX, offsetY + sizePart / 3 * 2);
  path.cubicTo(
      offsetX + bumpSize,
      offsetY + sizePart / 6 * 5,
      offsetX + bumpSize,
      offsetY + sizePart / 6,
      offsetX,
      offsetY + sizePart / 3);
  path.close();
  return path;
}

class PuzzlePieceClipper extends CustomClipper<Path> {
  PuzzlePieceClipper(this.height, this.width, this.x, this.y);
  final double width;
  final double height;
  final double x;
  final double y;
  @override
  Path getClip(Size size) {
    return getPiecePathCustom(size, x, y, width);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}