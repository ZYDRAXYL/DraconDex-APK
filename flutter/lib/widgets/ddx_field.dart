import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../core/theme/ddx_theme.dart';
import '../core/theme/tokens.g.dart' hide DdxGlass;

/// Field heights — `--ctl-sm/md/lg`.
enum DdxFieldSize { sm, md, lg }

/// The one text field (APP docs/COMPONENTS.md; EXE `.fg` + `:where(input)`):
/// sized by the control tokens, help or an error under it, and the disabled
/// and read-only states drawn the same everywhere. An error also marks the
/// field invalid for assistive tech — the desktop's `aria-invalid`.
class DdxField extends StatelessWidget {
  const DdxField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.size = DdxFieldSize.lg,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.prefixText,
    this.autocorrect = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helper;

  /// Shown under the field; non-null marks it invalid.
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final DdxFieldSize size;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;

  /// The counter is never drawn: a limit, not a prompt.
  final int? maxLength;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final String? prefixText;
  final bool autocorrect;

  static double heightOf(DdxFieldSize s) => switch (s) {
        DdxFieldSize.sm => DdxSize.ctlSm,
        DdxFieldSize.md => DdxSize.ctlMd,
        DdxFieldSize.lg => DdxSize.ctlLg,
      };

  @override
  Widget build(BuildContext context) {
    final ddx = context.ddx;
    final height = heightOf(size);
    // one line of body text is ~20dp; the rest is padding
    final vertical = ((height - 20) / 2).clamp(2.0, 12.0);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      autocorrect: autocorrect,
      inputFormatters: inputFormatters,
      style: TextStyle(color: enabled ? ddx.palette.t1 : ddx.textMuted),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        errorMaxLines: 3,
        helperMaxLines: 3,
        counterText: maxLength == null ? null : '',
        isDense: true,
        constraints: BoxConstraints(minHeight: height),
        contentPadding: EdgeInsets.symmetric(horizontal: DdxSpace.sp5, vertical: vertical),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        prefixText: prefixText,
        // read-only reads as a value, not as a box waiting for input
        fillColor: readOnly || !enabled ? ddx.palette.surface : null,
      ),
    );
    return Semantics(
      validationResult: errorText != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: field,
    );
  }
}
