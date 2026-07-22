import 'dart:math';

import '../tool_engine.dart';

/// ============================================================================
/// CALCULATOR / UTILITY ENGINES — pure Dart, fully offline.
/// ============================================================================

double _num(String s) {
  final v = double.tryParse(s.replaceAll(',', ''));
  if (v == null) throw ToolFailure('"$s" is not a number.');
  return v;
}

List<String> _tokens(String? text, int minCount, String usage) {
  final parts = (text ?? '')
      .trim()
      .split(RegExp(r'[\s,]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length < minCount) throw ToolFailure(usage);
  return parts;
}

String _money(num v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

/// Unit converter — "12 km mi" style input per category.
class UnitConvertEngine extends LocalToolEngine {
  static const _units = <String, Map<String, double>>{
    // factor → base unit of the category
    'Length': {
      'mm': 0.001, 'cm': 0.01, 'm': 1, 'km': 1000,
      'in': 0.0254, 'ft': 0.3048, 'yd': 0.9144, 'mi': 1609.344,
    },
    'Weight': {
      'mg': 0.000001, 'g': 0.001, 'kg': 1, 'ton': 1000,
      'oz': 0.0283495, 'lb': 0.453592,
    },
    'Data': {
      'b': 1, 'kb': 1024, 'mb': 1048576, 'gb': 1073741824,
      'tb': 1099511627776,
    },
    'Speed': {
      'kmh': 1, 'mph': 1.609344, 'ms': 3.6, 'knot': 1.852,
    },
  };

  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Convert',
        needsText: true,
        textHint: 'e.g. 12 km mi  •  2.5 kg lb  •  512 mb gb',
        choice: ToolChoiceSpec(
          optionKey: 'category',
          label: 'Category',
          options: ['Length', 'Weight', 'Temperature', 'Data', 'Speed'],
          defaultValue: 'Length',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final cat = input.option<String>('category') ?? 'Length';
    onProgress(null, 'Converting');

    if (cat == 'Temperature') {
      final t = _tokens(input.text, 2, 'Enter: value unit — e.g. 100 c');
      final v = _num(t[0]);
      final unit = t[1].toLowerCase().replaceAll('°', '');
      final (c, label) = switch (unit) {
        'c' || 'celsius' => (v, '$v °C'),
        'f' || 'fahrenheit' => ((v - 32) * 5 / 9, '$v °F'),
        'k' || 'kelvin' => (v - 273.15, '$v K'),
        _ => throw const ToolFailure('Unit must be C, F or K.'),
      };
      return ToolResult.text(
        '°C  ${c.toStringAsFixed(2)}\n'
        '°F  ${(c * 9 / 5 + 32).toStringAsFixed(2)}\n'
        'K   ${(c + 273.15).toStringAsFixed(2)}',
        summary: label,
      );
    }

    final table = _units[cat]!;
    final t = _tokens(
        input.text, 3, 'Enter: value from to — e.g. 12 km mi');
    final v = _num(t[0]);
    final from = t[1].toLowerCase();
    final to = t[2].toLowerCase();
    final f = table[from], g = table[to];
    if (f == null || g == null) {
      throw ToolFailure(
          'Unknown unit. $cat units: ${table.keys.join(', ')}');
    }
    final result = v * f / g;
    return ToolResult.text(
      '$v $from = ${result.toStringAsFixed(result.abs() < 10 ? 4 : 2)} $to',
      summary: cat,
    );
  }
}

/// Exact age from a date of birth.
class AgeCalcEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate Age',
        needsText: true,
        textHint: 'Date of birth — e.g. 1996-04-14',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final raw = (input.text ?? '').trim().replaceAll('/', '-');
    final dob = DateTime.tryParse(raw);
    if (dob == null) {
      throw const ToolFailure('Enter the date of birth as YYYY-MM-DD.');
    }
    final now = DateTime.now();
    if (dob.isAfter(now)) throw const ToolFailure('That date is in the future.');
    onProgress(null, 'Calculating');

    var years = now.year - dob.year;
    var months = now.month - dob.month;
    var days = now.day - dob.day;
    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    var nextBirthday = DateTime(now.year, dob.month, dob.day);
    if (!nextBirthday.isAfter(now)) {
      nextBirthday = DateTime(now.year + 1, dob.month, dob.day);
    }
    final untilBirthday = nextBirthday.difference(now).inDays;
    final totalDays = now.difference(dob).inDays;
    return ToolResult.text(
      'Age          $years years, $months months, $days days\n'
      'Total        $totalDays days (${(totalDays / 7).floor()} weeks)\n'
      'Next birthday in $untilBirthday day(s) 🎂',
      summary: '$years years old',
    );
  }
}

/// BMI from weight (kg) and height (cm).
class BmiEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate BMI',
        needsText: true,
        textHint: 'weight(kg) height(cm) — e.g. 70 175',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter: weight(kg) height(cm) — e.g. 70 175');
    final kg = _num(t[0]);
    final cm = _num(t[1]);
    if (kg <= 0 || cm <= 0) throw const ToolFailure('Values must be positive.');
    onProgress(null, 'Calculating');
    final bmi = kg / pow(cm / 100, 2);
    final range = switch (bmi) {
      < 18.5 => 'Underweight',
      < 25 => 'Healthy range',
      < 30 => 'Overweight',
      _ => 'Obese range',
    };
    final low = (18.5 * pow(cm / 100, 2));
    final high = (24.9 * pow(cm / 100, 2));
    return ToolResult.text(
      'BMI              ${bmi.toStringAsFixed(1)} — $range\n'
      'Healthy weight   ${low.toStringAsFixed(1)} – ${high.toStringAsFixed(1)} kg for ${_money(cm)} cm',
      summary: 'BMI ${bmi.toStringAsFixed(1)} • $range',
    );
  }
}

/// Percentage helper: % of, what %, and % change.
class PercentageEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'Two numbers — e.g. 15 200',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Mode',
          options: ['X% of Y', 'X is what % of Y', '% change X → Y'],
          defaultValue: 'X% of Y',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter two numbers — e.g. 15 200');
    final x = _num(t[0]);
    final y = _num(t[1]);
    onProgress(null, 'Calculating');
    final mode = input.option<String>('mode') ?? 'X% of Y';
    switch (mode) {
      case 'X is what % of Y':
        if (y == 0) throw const ToolFailure('Y cannot be zero.');
        return ToolResult.text(
            '${_money(x)} is ${(x / y * 100).toStringAsFixed(2)}% of ${_money(y)}',
            summary: mode);
      case '% change X → Y':
        if (x == 0) throw const ToolFailure('X cannot be zero.');
        final ch = (y - x) / x.abs() * 100;
        return ToolResult.text(
            '${_money(x)} → ${_money(y)} = ${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(2)}%',
            summary: mode);
      default:
        return ToolResult.text(
            '$x% of ${_money(y)} = ${_money(x / 100 * y)}',
            summary: mode);
    }
  }
}

/// Loan EMI calculator: principal, annual rate %, years.
class EmiEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate EMI',
        needsText: true,
        textHint: 'principal rate% years — e.g. 500000 8.5 20',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(
        input.text, 3, 'Enter: principal rate% years — e.g. 500000 8.5 20');
    final p = _num(t[0]);
    final annual = _num(t[1].replaceAll('%', ''));
    final years = _num(t[2]);
    if (p <= 0 || annual < 0 || years <= 0) {
      throw const ToolFailure('Values must be positive.');
    }
    onProgress(null, 'Calculating');
    final n = (years * 12).round();
    final r = annual / 12 / 100;
    final emi = r == 0 ? p / n : p * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
    final total = emi * n;
    return ToolResult.text(
      'Monthly EMI     ${_money(emi)}\n'
      'Total payment   ${_money(total)} over $n months\n'
      'Total interest  ${_money(total - p)}',
      summary: 'EMI ${_money(emi)}/month',
    );
  }
}

/// Simple / compound interest.
class InterestEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'principal rate% years — e.g. 100000 7 5',
        choice: ToolChoiceSpec(
          optionKey: 'kind',
          label: 'Interest',
          options: ['Compound (yearly)', 'Compound (monthly)', 'Simple'],
          defaultValue: 'Compound (yearly)',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(
        input.text, 3, 'Enter: principal rate% years — e.g. 100000 7 5');
    final p = _num(t[0]);
    final rate = _num(t[1].replaceAll('%', ''));
    final years = _num(t[2]);
    if (p <= 0 || rate < 0 || years <= 0) {
      throw const ToolFailure('Values must be positive.');
    }
    onProgress(null, 'Calculating');
    final kind = input.option<String>('kind') ?? 'Compound (yearly)';
    final amount = switch (kind) {
      'Simple' => p * (1 + rate / 100 * years),
      'Compound (monthly)' => p * pow(1 + rate / 100 / 12, 12 * years),
      _ => p * pow(1 + rate / 100, years),
    };
    return ToolResult.text(
      'Maturity amount  ${_money(amount)}\n'
      'Interest earned  ${_money(amount - p)}\n'
      'Growth           ${((amount / p - 1) * 100).toStringAsFixed(1)}%',
      summary: kind,
    );
  }
}

/// Discount calculator: price and discount %.
class DiscountEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'price discount% — e.g. 1999 25',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter: price discount% — e.g. 1999 25');
    final price = _num(t[0]);
    final pct = _num(t[1].replaceAll('%', ''));
    onProgress(null, 'Calculating');
    final off = price * pct / 100;
    return ToolResult.text(
      'You pay    ${_money(price - off)}\n'
      'You save   ${_money(off)} ($pct% off ${_money(price)})',
      summary: '${_money(price - off)} after $pct% off',
    );
  }
}

/// Tip / bill split calculator.
class TipEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Split Bill',
        needsText: true,
        textHint: 'bill tip% people — e.g. 2400 10 4',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter: bill tip% [people] — e.g. 2400 10 4');
    final bill = _num(t[0]);
    final tip = _num(t[1].replaceAll('%', ''));
    final people = t.length > 2 ? _num(t[2]).round() : 1;
    if (people < 1) throw const ToolFailure('People must be at least 1.');
    onProgress(null, 'Calculating');
    final total = bill * (1 + tip / 100);
    return ToolResult.text(
      'Tip         ${_money(bill * tip / 100)}\n'
      'Total       ${_money(total)}\n'
      'Per person  ${_money(total / people)} ($people people)',
      summary: '${_money(total / people)} each',
    );
  }
}

/// GST / VAT calculator (add or remove tax).
class GstEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'amount rate% — e.g. 1000 18',
        choice: ToolChoiceSpec(
          optionKey: 'mode',
          label: 'Mode',
          options: ['Add tax', 'Remove tax'],
          defaultValue: 'Add tax',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter: amount rate% — e.g. 1000 18');
    final amount = _num(t[0]);
    final rate = _num(t[1].replaceAll('%', ''));
    onProgress(null, 'Calculating');
    if ((input.option<String>('mode') ?? 'Add tax') == 'Remove tax') {
      final base = amount / (1 + rate / 100);
      return ToolResult.text(
        'Base amount  ${_money(base)}\n'
        'Tax portion  ${_money(amount - base)} ($rate% included)',
        summary: 'Tax removed',
      );
    }
    final tax = amount * rate / 100;
    return ToolResult.text(
      'Tax          ${_money(tax)} ($rate%)\n'
      'Grand total  ${_money(amount + tax)}',
      summary: 'Tax added',
    );
  }
}

/// Days / weeks / months between two dates.
class DateDiffEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'Two dates — e.g. 2026-01-01 2026-07-20',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(
        input.text, 2, 'Enter two dates — e.g. 2026-01-01 2026-07-20');
    final a = DateTime.tryParse(t[0].replaceAll('/', '-'));
    final b = DateTime.tryParse(t[1].replaceAll('/', '-'));
    if (a == null || b == null) {
      throw const ToolFailure('Use YYYY-MM-DD for both dates.');
    }
    onProgress(null, 'Calculating');
    final days = b.difference(a).inDays.abs();
    return ToolResult.text(
      'Days     $days\n'
      'Weeks    ${(days / 7).toStringAsFixed(1)}\n'
      'Months   ~${(days / 30.44).toStringAsFixed(1)}\n'
      'Years    ~${(days / 365.25).toStringAsFixed(2)}',
      summary: '$days days apart',
    );
  }
}

/// Random number in a range (secure RNG).
class RandomNumberEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Generate',
        needsText: true,
        regenerable: true,
        textHint: 'min max — e.g. 1 100',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 2, 'Enter: min max — e.g. 1 100');
    final lo = _num(t[0]).round();
    final hi = _num(t[1]).round();
    if (hi <= lo) throw const ToolFailure('Max must be greater than min.');
    onProgress(null, 'Rolling');
    final v = lo + Random.secure().nextInt(hi - lo + 1);
    return ToolResult.text('$v', summary: 'Between $lo and $hi');
  }
}

/// Coin flip / dice roller.
class DiceEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Roll',
        regenerable: true,
        choice: ToolChoiceSpec(
          optionKey: 'die',
          label: 'Roll',
          options: ['Coin flip', 'D6', '2 × D6', 'D20'],
          defaultValue: 'Coin flip',
        ),
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    onProgress(null, 'Rolling');
    final r = Random.secure();
    final die = input.option<String>('die') ?? 'Coin flip';
    final out = switch (die) {
      'D6' => '🎲 ${r.nextInt(6) + 1}',
      '2 × D6' => () {
          final a = r.nextInt(6) + 1, b = r.nextInt(6) + 1;
          return '🎲 $a + $b = ${a + b}';
        }(),
      'D20' => '🎲 ${r.nextInt(20) + 1}',
      _ => r.nextBool() ? '🪙 Heads' : '🪙 Tails',
    };
    return ToolResult.text(out, summary: die);
  }
}

/// Fuel cost for a trip: distance, mileage, fuel price.
class FuelCostEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Calculate',
        needsText: true,
        textHint: 'distance(km) mileage(km/l) price/l — e.g. 350 18 105',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final t = _tokens(input.text, 3,
        'Enter: distance mileage price — e.g. 350 18 105');
    final dist = _num(t[0]);
    final mileage = _num(t[1]);
    final price = _num(t[2]);
    if (dist <= 0 || mileage <= 0 || price < 0) {
      throw const ToolFailure('Values must be positive.');
    }
    onProgress(null, 'Calculating');
    final litres = dist / mileage;
    return ToolResult.text(
      'Fuel needed  ${litres.toStringAsFixed(1)} L\n'
      'Trip cost    ${_money(litres * price)}\n'
      'Per km       ${_money(litres * price / dist)}',
      summary: '${_money(litres * price)} for ${_money(dist)} km',
    );
  }
}

/// Password strength analysis (entropy + practical checks). Nothing leaves
/// the device.
class PasswordStrengthEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Check Strength',
        needsText: true,
        textHint: 'Enter a password to check…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final pw = input.text ?? '';
    if (pw.isEmpty) throw const ToolFailure('Enter a password.');
    onProgress(null, 'Analyzing');

    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(pw)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(pw)) pool += 26;
    if (RegExp(r'[0-9]').hasMatch(pw)) pool += 10;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) pool += 33;
    final entropy = pw.length * (log(max(pool, 2)) / ln2);

    final issues = <String>[
      if (pw.length < 12) '• Use at least 12 characters',
      if (!RegExp(r'[A-Z]').hasMatch(pw)) '• Add uppercase letters',
      if (!RegExp(r'[0-9]').hasMatch(pw)) '• Add digits',
      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) '• Add symbols',
      if (RegExp(r'(.)\1{2,}').hasMatch(pw)) '• Avoid repeated characters',
      if (RegExp(r'(?:123|abc|qwe|password)', caseSensitive: false)
          .hasMatch(pw))
        '• Avoid common sequences',
    ];
    final verdict = switch (entropy) {
      < 40 => 'Weak 🔴',
      < 60 => 'Fair 🟠',
      < 80 => 'Strong 🟢',
      _ => 'Excellent 🟢🟢',
    };
    final body = StringBuffer()
      ..writeln('Strength   $verdict')
      ..writeln('Entropy    ~${entropy.round()} bits')
      ..writeln('Length     ${pw.length} characters');
    if (issues.isNotEmpty) {
      body
        ..writeln()
        ..writeln('Suggestions:')
        ..writeln(issues.join('\n'));
    }
    return ToolResult.text(body.toString().trimRight(), summary: verdict);
  }
}

/// Card number validator (Luhn checksum, offline, nothing stored).
class LuhnEngine extends LocalToolEngine {
  @override
  ToolSpec get spec => const ToolSpec(
        actionLabel: 'Validate',
        needsText: true,
        textHint: 'Card number — digits only…',
      );

  @override
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  }) async {
    final digits = (input.text ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{8,19}$').hasMatch(digits)) {
      throw const ToolFailure('Enter 8–19 digits.');
    }
    onProgress(null, 'Validating');
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = int.parse(digits[i]);
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    final valid = sum % 10 == 0;
    final network = switch (digits[0]) {
      '4' => 'Visa',
      '5' => 'Mastercard',
      '3' => 'Amex / Diners',
      '6' => 'Discover / RuPay',
      _ => 'Unknown network',
    };
    final masked =
        '${digits.substring(0, 4)} •••• ${digits.substring(digits.length - 4)}';
    return ToolResult.text(
      '$masked\nChecksum   ${valid ? '✓ VALID' : '✗ INVALID'}\nNetwork    $network\n\nValidated on-device — nothing is stored or sent.',
      summary: valid ? 'Valid (Luhn)' : 'Invalid checksum',
    );
  }
}
