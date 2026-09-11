// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

// ─── Individual Question Widgets ────────────────────────────────────────────
// Each question is its own StatefulWidget so that setState() only
// rebuilds the ONE question card that changed, not the entire dialog.

class _SingleChoiceQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final String? currentValue;
  final ValueChanged<String?> onChanged;

  const _SingleChoiceQuestion({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<_SingleChoiceQuestion> createState() => _SingleChoiceQuestionState();
}

class _SingleChoiceQuestionState extends State<_SingleChoiceQuestion> {
  String? _selected;
  late final TextEditingController _customInputController;
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
    _customInputController = TextEditingController();
  }

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  bool _isOptionRequiringInput(String optStr) {
    final lower = optStr.toLowerCase();
    return lower.contains('enter') ||
        lower.contains('select') ||
        lower.contains('specify') ||
        lower.contains('specific past date') ||
        lower.contains('other');
  }

  bool _isDateContext(String optStr) {
    final q = widget.question;
    final id = (q['id'] ?? '').toString().toLowerCase();
    final title = (q['title'] ?? '').toString().toLowerCase();
    final qText = (q['question'] ?? '').toString().toLowerCase();
    final optLower = optStr.toLowerCase();

    return id.contains('date') ||
        title.contains('date') ||
        qText.contains('date') ||
        optLower.contains('date');
  }

  Future<void> _pickDateForOption(String optStr) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _pickedDate = picked;
        _customInputController.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] Picked date: $formatted for question ${widget.question['id']}');
    }
  }

  void _handleOptionSelection(String optStr) {
    setState(() => _selected = optStr);
    if (_isOptionRequiringInput(optStr)) {
      if (_isDateContext(optStr)) {
        if (_customInputController.text.isNotEmpty) {
          widget.onChanged(_customInputController.text);
        } else {
          widget.onChanged(optStr);
          _pickDateForOption(optStr);
        }
      } else {
        widget.onChanged(_customInputController.text.isNotEmpty ? "$optStr: ${_customInputController.text}" : optStr);
      }
    } else {
      widget.onChanged(optStr);
    }
    developer.log('[Clarification] Single choice selected: $optStr for question ${widget.question['id']}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final options = List<dynamic>.from(widget.question['options'] ?? []);

    if (options.isEmpty) {
      return _TextInputWidget(
        question: widget.question,
        onChanged: (val) => widget.onChanged(val),
      );
    }

    return Column(
      children: options.map((opt) {
        final optStr = opt.toString();
        final isSelected = _selected == optStr;
        final requiresInput = _isOptionRequiringInput(optStr);
        final isDate = _isDateContext(optStr);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleOptionSelection(optStr),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withAlpha(25) : surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: optStr,
                            groupValue: _selected,
                            onChanged: (val) {
                              if (val != null) _handleOptionSelection(val);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              optStr,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      if (isSelected && requiresInput) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 48, right: 8, bottom: 8),
                          child: isDate
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _pickDateForOption(optStr),
                                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                                      label: Text(
                                        _pickedDate != null
                                            ? DateFormat('dd-MMM-yyyy').format(_pickedDate!)
                                            : 'Select Date from Calendar',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _customInputController,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Or enter date (e.g. 15-Feb-2026)',
                                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        isDense: true,
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 16),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                                          onPressed: () => _pickDateForOption(optStr),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.withAlpha(50)),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        widget.onChanged(val.trim().isEmpty ? null : val.trim());
                                      },
                                    ),
                                  ],
                                )
                              : TextFormField(
                                  controller: _customInputController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Please specify details...',
                                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.withAlpha(50)),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    widget.onChanged(val.trim().isEmpty ? null : "$optStr: ${val.trim()}");
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MultiChoiceQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final List<String> currentValues;
  final ValueChanged<List<String>> onChanged;

  const _MultiChoiceQuestion({
    super.key,
    required this.question,
    required this.currentValues,
    required this.onChanged,
  });

  @override
  State<_MultiChoiceQuestion> createState() => _MultiChoiceQuestionState();
}

class _MultiChoiceQuestionState extends State<_MultiChoiceQuestion> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.currentValues);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final options = List<dynamic>.from(widget.question['options'] ?? []);

    if (options.isEmpty) {
      return _TextInputWidget(
        question: widget.question,
        onChanged: (val) => widget.onChanged(val != null ? [val] : []),
      );
    }

    return Column(
      children: options.map((opt) {
        final optStr = opt.toString();
        final isSelected = _selected.contains(optStr);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withAlpha(25) : surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: CheckboxListTile(
                dense: true,
                title: Text(optStr, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                value: isSelected,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selected.add(optStr);
                    } else {
                      _selected.remove(optStr);
                    }
                  });
                  widget.onChanged(List<String>.from(_selected));
                  developer.log('[Clarification] Multi-choice updated: $_selected for question ${widget.question['id']}');
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BooleanQuestion extends StatefulWidget {
  final Map<String, dynamic> question;
  final bool? currentValue;
  final ValueChanged<bool> onChanged;

  const _BooleanQuestion({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<_BooleanQuestion> createState() => _BooleanQuestionState();
}

class _BooleanQuestionState extends State<_BooleanQuestion> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          dense: true,
          title: const Text('Yes / No', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          value: _value,
          onChanged: (val) {
            setState(() => _value = val);
            widget.onChanged(val);
            developer.log('[Clarification] Boolean changed: $val for question ${widget.question['id']}');
          },
        ),
      ),
    );
  }
}

class _TextInputWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final ValueChanged<String?> onChanged;

  const _TextInputWidget({super.key, required this.question, required this.onChanged});

  @override
  State<_TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<_TextInputWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDateContext {
    final q = widget.question;
    final id = (q['id'] ?? '').toString().toLowerCase();
    final title = (q['title'] ?? '').toString().toLowerCase();
    final qText = (q['question'] ?? '').toString().toLowerCase();
    final type = (q['type'] ?? '').toString().toLowerCase();
    return type == 'date' ||
        type == 'datetime' ||
        id.contains('date') ||
        title.contains('date') ||
        qText.contains('date');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _controller.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] TextInput picked date: $formatted for question ${widget.question['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    final type = widget.question['type'] ?? 'text';
    final isDate = _isDateContext;

    return TextFormField(
      controller: _controller,
      keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
      onChanged: (val) {
        widget.onChanged(val.isEmpty ? null : val);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: surfaceColor,
        hintText: isDate ? 'e.g., 15-Feb-2026 (or tap calendar)' : null,
        prefixIcon: isDate ? const Icon(Icons.edit_calendar_rounded, size: 18) : null,
        suffixIcon: isDate
            ? IconButton(
                icon: const Icon(Icons.calendar_today_rounded, size: 20),
                onPressed: _pickDate,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _DateQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> question;
  final String? currentValue;
  final ValueChanged<String?> onChanged;

  const _DateQuestionWidget({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<_DateQuestionWidget> createState() => _DateQuestionWidgetState();
}

class _DateQuestionWidgetState extends State<_DateQuestionWidget> {
  late final TextEditingController _controller;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      final formatted = DateFormat('dd-MMM-yyyy').format(picked);
      setState(() {
        _selectedDate = picked;
        _controller.text = formatted;
      });
      widget.onChanged(formatted);
      developer.log('[Clarification] DateQuestionWidget picked date: $formatted for question ${widget.question['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate != null ? theme.colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: _selectedDate != null ? theme.colorScheme.primary : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _controller.text.isNotEmpty ? _controller.text : 'Select Date from Calendar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _controller.text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                      color: _controller.text.isNotEmpty
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  label: const Text('Pick', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          onChanged: (val) {
            widget.onChanged(val.trim().isEmpty ? null : val.trim());
          },
          decoration: InputDecoration(
            hintText: 'Or enter date manually (e.g. 15-Feb-2026)',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            filled: true,
            fillColor: surfaceColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Main Dialog ─────────────────────────────────────────────────────────────

class ClarificationDialog extends StatefulWidget {
  final Map<String, dynamic> clarificationData;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onCancel;

  const ClarificationDialog({
    super.key,
    required this.clarificationData,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ClarificationDialog> createState() => _ClarificationDialogState();
}

class _ClarificationDialogState extends State<ClarificationDialog> {
  // Answers stored centrally in the parent dialog, but individual
  // question widgets manage their own visual state locally.
  final Map<String, dynamic> _answers = {};
  late final List<dynamic> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.clarificationData['questions'] ?? [];
    developer.log('[Clarification] Dialog opened with ${_questions.length} questions: '
        '${_questions.map((q) => q['id']).toList()}');
  }

  bool _canSubmit() {
    for (var q in _questions) {
      if (q['required'] == true) {
        final answer = _answers[q['id']];
        if (answer == null) return false;
        if (answer is String && answer.trim().isEmpty) return false;
        if (answer is List && answer.isEmpty) return false;
      }
    }
    return true;
  }

  void _onAnswerChanged(String questionId, dynamic value) {
    setState(() {
      _answers[questionId] = value;
    });
    developer.log('[Clarification] Answer stored: $questionId = $value');
  }

  void _handleSubmit() {
    developer.log('[Clarification] Submit pressed. Payload: $_answers');
    widget.onSubmit(Map<String, dynamic>.from(_answers));
  }

  Widget _buildQuestionInput(Map<String, dynamic> q) {
    final String type = (q['type'] ?? 'text').toString().toLowerCase();
    final String id = (q['id'] ?? '').toString();
    final String title = (q['title'] ?? '').toString();
    final String qText = (q['question'] ?? '').toString();
    final options = List<dynamic>.from(q['options'] ?? []);

    final bool isDate = type == 'date' ||
        type == 'datetime' ||
        (options.isEmpty &&
            (id.toLowerCase().contains('date') ||
                title.toLowerCase().contains('date') ||
                qText.toLowerCase().contains('date')));

    if (isDate) {
      return _DateQuestionWidget(
        key: ValueKey('date_$id'),
        question: q,
        currentValue: _answers[id] as String?,
        onChanged: (val) => _onAnswerChanged(id, val),
      );
    }

    switch (type) {
      case 'date':
      case 'datetime':
        return _DateQuestionWidget(
          key: ValueKey('date_$id'),
          question: q,
          currentValue: _answers[id] as String?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'single_choice':
        return _SingleChoiceQuestion(
          key: ValueKey('sc_$id'),
          question: q,
          currentValue: _answers[id] as String?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'multi_choice':
        return _MultiChoiceQuestion(
          key: ValueKey('mc_$id'),
          question: q,
          currentValues: (_answers[id] as List<String>?) ?? [],
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'boolean':
        return _BooleanQuestion(
          key: ValueKey('bool_$id'),
          question: q,
          currentValue: _answers[id] as bool?,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
      case 'text':
      case 'number':
      default:
        return _TextInputWidget(
          key: ValueKey('text_$id'),
          question: q,
          onChanged: (val) => _onAnswerChanged(id, val),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final Color primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withAlpha(38)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(31),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.help_outline_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clarification Needed',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Answer to complete your coverage analysis.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Questions ─────────────────────────────────
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 1, right: 10),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q['title'] ?? 'Question ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q['question'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textColor.withAlpha(191),
                                      height: 1.4,
                                    ),
                                  ),
                                  if (q['reason'] != null && (q['reason'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withAlpha(77)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 1.0),
                                            child: Icon(Icons.info_outline, size: 13, color: Colors.amber.shade700),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              q['reason'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Input widget — isolated StatefulWidget per question
                        _buildQuestionInput(q),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.withAlpha(38))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        developer.log('[Clarification] Cancel pressed');
                        widget.onCancel();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: textSecondary,
                        side: BorderSide(color: Colors.grey.withAlpha(102)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canSubmit() ? _handleSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryColor.withAlpha(77),
                        disabledForegroundColor: Colors.white.withAlpha(153),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Submit Answers',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
