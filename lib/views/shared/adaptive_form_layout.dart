// lib/views/shared/adaptive_form_layout.dart
//
// Widget بيستخدم في كل فورمز التطبيق (الموظف، الرواتب، القواعد...) عشان
// يوحّد شكل عرض الحقول:
//   - موبايل / أندرويد ضيق  -> عمود واحد (Column) الحقول تحت بعض full-width.
//   - تابلت / ويندوز واسع    -> شبكة (Wrap) الحقول جنب بعض بعرض متساوي،
//                                مع تحديد أقصى عرض للمحتوى عشان الفورم ما
//                                يتمططش بشكل غير مريح على شاشة عريضة جدًا.
//
// الاستخدام داخل أي فورم:
//
//   AdaptiveFormLayout(
//     children: [
//       AdaptiveFormField(child: TextFormField(...)),
//       AdaptiveFormField(child: TextFormField(...)),
//       AdaptiveFormField(fullWidth: true, child: TextFormField(...)), // ياخد السطر كله دايمًا
//     ],
//   )

import 'package:flutter/material.dart';
import '../../core/responsive/breakpoints.dart';

/// عنصر واحد جوه [AdaptiveFormLayout].
/// [fullWidth] = true معناها الحقل ده دايمًا ياخد عرض السطر كامل
/// (زي حقول العنوان الطويلة، أو ملاحظات، حتى في وضع الديسكتوب).
class AdaptiveFormField extends StatelessWidget {
  final Widget child;
  final bool fullWidth;

  const AdaptiveFormField({
    super.key,
    required this.child,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => child;
}

class AdaptiveFormLayout extends StatelessWidget {
  /// الحقول المطلوب عرضها. يفضّل استخدام [AdaptiveFormField] لكل عنصر،
  /// لكن أي Widget عادي بيتقبل برضو (بيتعامل معاه كحقل نص عادي).
  final List<Widget> children;

  /// المسافة الأفقية بين الحقول في وضع الشبكة (تابلت/ديسكتوب).
  final double horizontalSpacing;

  /// المسافة الرأسية بين الحقول (كل الأوضاع).
  final double verticalSpacing;

  const AdaptiveFormLayout({
    super.key,
    required this.children,
    this.horizontalSpacing = 16,
    this.verticalSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final columns = context.responsiveColumns;

    // موبايل: عمود واحد بسيط - نفس السلوك الأصلي بالظبط.
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacing(children, verticalSpacing),
      );
    }

    // تابلت/ديسكتوب: شبكة بعرض متساوي لكل عمود، مع دعم fullWidth.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > Breakpoints.maxContentWidth
            ? Breakpoints.maxContentWidth
            : constraints.maxWidth;

        final itemWidth =
            (maxWidth - (horizontalSpacing * (columns - 1))) / columns;

        return Center(
          child: SizedBox(
            width: maxWidth,
            child: Wrap(
              spacing: horizontalSpacing,
              runSpacing: verticalSpacing,
              children: children.map((child) {
                final isFullWidth =
                    child is AdaptiveFormField && child.fullWidth;
                return SizedBox(
                  width: isFullWidth ? maxWidth : itemWidth,
                  child: child is AdaptiveFormField ? child.child : child,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double space) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      result.add(item is AdaptiveFormField ? item.child : item);
      if (i != items.length - 1) result.add(SizedBox(height: space));
    }
    return result;
  }
}
