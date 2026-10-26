import 'package:flutter_screenutil/flutter_screenutil.dart';

double screenHorizPadding = ScreenUtil().setWidth(16);

class ResSize {
  static double get h => ScreenUtil().scaleHeight;
  static double get w => ScreenUtil().scaleWidth;
  static double setWidth(double size) => ScreenUtil().setWidth(size);
  static double setHeight(double size) => ScreenUtil().setHeight(size);

  static double setSp(double fontSize) =>
      ScreenUtil().setSp(fontSize).clamp(fontSize * .85, fontSize * 1.2);
}
