import 'package:flutter/material.dart';

class InputFields {
  static Widget oneShortTitle({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'One-Short Title',
      hint: 'Demo Title Name',
      value: value,
      onChanged: onChanged,
    );
  }

  static Widget seriesTitle({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'Series Title',
      hint: 'Series Title Name',
      value: value,
      onChanged: onChanged,
    );
  }

  static Widget passcode({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'PassCode Number',
      hint: 'PassCode Number',
      value: value,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
    );
  }

  static Widget episodeTitleSeries({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'Episode Title',
      hint: 'Episode Title',
      value: value,
      onChanged: onChanged,
      suffix: const Text('ep-1'),
    );
  }

  static Widget description({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'Description',
      hint: 'Enter description...',
      value: value,
      onChanged: onChanged,
      maxLines: 4,
    );
  }

  static Widget episodeTitlePrompt({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _buildInputField(
      label: 'Episode Name',
      hint: 'Ep Title Name',
      value: value,
      onChanged: onChanged,
    );
  }

  static Widget _buildInputField({
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffix: suffix,
            ),
          ),
        ],
      ),
    );
  }
}




