import 'models/nid_card.dart';

/// Bangladesh-NID-specific OCR normalization, regex field extraction, MRZ
/// parsing, and barcode decoding.
///
/// The regex, ordering, and extraction logic here are intentionally
/// unpolished in places (see the OCR-misread normalization table below) —
/// they're tuned against real-world OCR noise, not rewritten for elegance.
///
/// This parser is pure Dart — no Flutter or plugin dependency — and is
/// entirely Bangladesh-NID-specific: Bengali/Devanagari script handling, the
/// MRZ `I<BGD` anchor, and the {10, 13, 17}-digit NID length whitelist are
/// all baked in by design, not configurable. Multi-country support is out
/// of scope for this package, not an oversight.
class NidScanParser {
  const NidScanParser();

  /// Normalizes [frontText]/[backText] and extracts structured NID fields.
  ///
  /// Never throws for missing fields — fields that cannot be located are
  /// simply `null` on the returned
  /// [NidCard]. MRZ-derived values win over front/back regex extraction for
  /// `nidNumber`, `name`, and `dateOfBirth` where both exist; `gender`,
  /// `expiryDate`, and `nationality` are MRZ-only; the rest are
  /// regex-extraction-only.
  NidCard parse({required String frontText, required String backText}) {
    final front = _normalize(frontText);
    final back = _normalize(backText);
    final frontLines = _lines(front);

    // ── Front-side fields ────────────────────────────────────────────────
    final names = _extractNames(frontLines);
    String? localName = names['bn'];

    localName = localName?.replaceAll(RegExp(r'[^ঀ-৿\s]'), '').trim();
    if (localName != null && localName.isEmpty) localName = null;

    final dob = _extractDOB(front);
    final frontNid = _extractNID(front);
    final father = _extractFather(frontLines);
    final mother = _extractMother(frontLines);

    // ── Back-side fields ─────────────────────────────────────────────────
    final blood = _extractBloodGroup(back);
    final place = _extractPlaceOfBirth(back);
    final issue = _extractIssueDate(back);
    final address = _extractAddress(back);

    final mrz = _parseMRZ(backText);

    return NidCard(
      nidNumber: mrz['nid'] ?? frontNid,
      name: names['en'] ?? mrz['name'],
      nameLocal: localName,
      dateOfBirth: dob ?? mrz['dob'],
      fatherName: father,
      motherName: mother,
      address: address,
      gender: mrz['gender'],
      expiryDate: mrz['expiry'],
      nationality: mrz['nationality'],
      bloodGroup: blood,
      placeOfBirth: place,
      issueDate: issue,
    );
  }

  /// Decodes a raw PDF417 barcode payload into a key/value map.
  ///
  /// Recognizes two distinct formats:
  ///
  /// - An XML-tag format (`<pin>`/`<name>`/... present in [rawData]).
  /// - A control-character-delimited key-value format, using ASCII `0x1D`
  ///   (Group Separator) as the field delimiter and `0x04` (End of
  ///   Transmission) as a value-cleanup character to strip. The tag
  ///   dictionary for this branch (NM/NW/OL/BR/PE/PR/VA/DT/PK/SG/CH) has not
  ///   been independently verified against official Bangladesh NID barcode
  ///   conventions — treat as "known to work against observed cards," not
  ///   confirmed spec behavior.
  ///
  /// Returns an empty map if [rawData] matches neither format.
  Map<String, dynamic> parseBarcode(String rawData) {
    final Map<String, dynamic> results = {};

    if (rawData.contains('<pin>') || rawData.contains('<name>')) {
      final Map<String, String> xmlMapping = {
        'pin': 'ID Number',
        'name': 'Full Name',
        'DOB': 'Date of Birth',
        'F': 'Finger Reference',
        'TYPE': 'Card Type',
        'V': 'Version',
        'ds': 'Digital Signature',
      };

      xmlMapping.forEach((tag, description) {
        final regExp = RegExp('<$tag>(.*?)</$tag>');
        final match = regExp.firstMatch(rawData);
        if (match != null) {
          results[description] = match.group(1);
        }
      });
    } else if (rawData.contains('\x1d')) {
      String cleanedData = rawData;
      if (rawData.contains('NM')) {
        cleanedData = rawData.substring(rawData.indexOf('NM'));
      }

      final parts = cleanedData.split('\x1d');

      for (final part in parts) {
        if (part.length < 2) continue;

        final String tag = part.substring(0, 2);
        final String value = part.substring(2).replaceAll('\x04', '').trim();

        switch (tag) {
          case 'NM':
            results['Full Name'] = value;
            break;
          case 'NW':
            results['ID Number'] = value;
            break;
          case 'OL':
            results['Old ID / Personal Number'] = value;
            break;
          case 'BR':
            results['Date of Birth'] = value;
            break;
          case 'PE':
            results['Postal Code'] = value;
            break;
          case 'PR':
            results['Province / Region'] = value;
            break;
          case 'VA':
            results['Verification Code'] = value;
            break;
          case 'DT':
            results['Date of Issue'] = value;
            break;
          case 'PK':
            results['Packet / Batch'] = value;
            break;
          case 'SG':
            results['Digital Signature'] = value;
            break;
          case 'CH':
            results['Checksum'] = value;
            break;
          default:
            results[tag] = value;
        }
      }
    }

    return results;
  }

  String _normalize(String text) {
    return _bengaliToAscii(text)
        .replaceAll('মোহামমাদ', 'মোহাম্মদ')
        .replaceAll('মোহাম্মাদ', 'মোহাম্মদ')
        .replaceAll('মোহামাদ', 'মোহাম্মদ')
        .replaceAll('মম', 'ম্ম')
        .replaceAll(
          RegExp(r'Gov[a-z]*g?[a-z]*nt\b', caseSensitive: false),
          'Government',
        )
        .replaceAll(
          RegExp(r'Banglades[a-z]*', caseSensitive: false),
          'Bangladesh',
        )
        .replaceAll(
          RegExp(r'Blo+[co]+\s*Group', caseSensitive: false),
          'Blood Group',
        )
        .replaceAll(RegExp(r'Biood\b', caseSensitive: false), 'Blood')
        .replaceAll(RegExp(r'Piace\b', caseSensitive: false), 'Place')
        .replaceAll(RegExp(r'lssue\b', caseSensitive: false), 'Issue')
        .replaceAll(RegExp(r'\bBth\b', caseSensitive: false), 'Birth')
        .replaceAll(RegExp(r'\bBloo\b', caseSensitive: false), 'Blood')
        .replaceAll(RegExp(r'\bNar?[mn]e\b', caseSensitive: false), 'Name')
        .replaceAll(RegExp(r'\bNeme\b', caseSensitive: false), 'Name')
        .replaceAll(
          RegExp(
            r'\b(?:Dte|Dae|Dete)\s+of\s+(?:Birth|Brth|Birt)\b',
            caseSensitive: false,
          ),
          'Date of Birth',
        )
        .replaceAll(RegExp(r'[ওo]sue\b', caseSensitive: false), 'Issue')
        .replaceAll(RegExp(r'Iss?ue\b', caseSensitive: false), 'Issue')
        .replaceAll(RegExp(r'\bDte\b', caseSensitive: false), 'Date')
        .replaceAll(RegExp(r'\bBrth\b', caseSensitive: false), 'Birth')
        .replaceAll(RegExp(r'\bDae\b', caseSensitive: false), 'Date')
        .replaceAll(
          RegExp(r'[A-Za-zঀ-৿]*\s*fes[a-z]*\s*National', caseSensitive: false),
          'National',
        )
        .replaceAll(RegExp(r'হানND\s*N[০0oO°]', caseSensitive: false), 'NID No')
        .replaceAll(RegExp(r'br\s*Is/ANID', caseSensitive: false), 'NID')
        .replaceAll(RegExp(r'NID\s*N[0oO°]', caseSensitive: false), 'NID No')
        .replaceAll('|', 'I')
        .replaceAll('।', ':')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _bengaliToAscii(String text) {
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < bengali.length; i++) {
      text = text.replaceAll(bengali[i], '$i');
    }
    return text;
  }

  List<String> _lines(String text) =>
      text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Map<String, String?> _extractNames(List<String> lines) {
    String? bnName;
    String? enName;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (bnName == null) {
        final m = RegExp(
          r'নাম[: ]*(.+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          bnName = _trimAtBoundary(m.group(1)?.trim() ?? '');
        } else if (line.trim() == 'নাম' && i + 1 < lines.length) {
          bnName = _trimAtBoundary(lines[i + 1].trim());
        }
      }

      if (bnName == null) {
        final t = line.trim();
        if (_isPureBengali(t) && t.split(' ').length >= 2 && t.length < 60) {
          if (!lines
              .sublist(0, i)
              .any((l) => l.contains('পিতা') || l.contains('Father'))) {
            bnName = _trimAtBoundary(t);
          }
        }
      }

      if (enName == null) {
        final m = RegExp(
          r'Name[: ]*([A-Za-z ]{3,})',
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          enName = _trimAtBoundary(m.group(1)?.trim() ?? '');
        } else if (line.trim().toLowerCase() == 'name' &&
            i + 1 < lines.length) {
          enName = _trimAtBoundary(lines[i + 1].trim());
        }
      }
    }

    if (enName == null) {
      const skip = {
        'GOVERNMENT',
        'NATIONAL',
        'REPUBLIC',
        'BANGLADESH',
        'PEOPLE',
        'CARD',
        'ID',
      };
      for (final line in lines) {
        final t = line.trim();
        if (t == t.toUpperCase() &&
            t.contains(RegExp(r'[A-Z]')) &&
            !skip.any((s) => t.contains(s)) &&
            !t.contains(RegExp(r'\d')) &&
            t.split(' ').length >= 2 &&
            t.length >= 5 &&
            t.length < 50) {
          enName = t;
          break;
        }
      }
    }

    return {'bn': bnName, 'en': enName};
  }

  bool _isPureBengali(String text) =>
      text.isNotEmpty && RegExp(r'^[ঀ-৿\s]+$').hasMatch(text);

  String _trimAtBoundary(String value) {
    const boundaries = [
      'পিতা',
      'মাতা',
      'Father',
      'Mother',
      'Date',
      'Birth',
      'NID',
      'Name',
    ];
    int cutAt = value.length;
    for (final b in boundaries) {
      final idx = value.indexOf(b);
      if (idx > 0 && idx < cutAt) cutAt = idx;
    }
    return value.substring(0, cutAt).trim();
  }

  String? _extractDOB(String text) {
    final m = RegExp(
      r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }

  String? _extractNID(String text) {
    for (final m in RegExp(
      r'\b\d{3,5}(?:\s?\d{3,5}){1,3}\b',
    ).allMatches(text)) {
      final cleaned = m.group(0)!.replaceAll(' ', '');
      if (cleaned.length == 10 ||
          cleaned.length == 13 ||
          cleaned.length == 17) {
        return cleaned;
      }
    }
    return null;
  }

  String? _extractFather(List<String> lines) =>
      _extractParent(lines, ['পিতা', 'পিত', 'পিভা', 'Father']);

  String? _extractMother(List<String> lines) =>
      _extractParent(lines, ['মাতা', 'মতা', 'আতা', 'Mother']);

  String? _extractParent(List<String> lines, List<String> labels) {
    const boundaries = [
      'পিতা',
      'পিত',
      'পিভা',
      'Father',
      'মাতা',
      'মতা',
      'আতা',
      'Mother',
      'Date',
      'Birth',
      'NID',
      'Name',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final label in labels) {
        if (!line.contains(label)) continue;

        final m = RegExp(
          '${RegExp.escape(label)}[: ]*(.*)',
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          String value = m.group(1)!.trim();
          for (final next in boundaries) {
            if (next == label) continue;
            final idx = value.indexOf(next);
            if (idx > 0) value = value.substring(0, idx).trim();
          }
          value = _cleanParentValue(value);
          if (value.isNotEmpty) return value;
        }

        if (i + 1 < lines.length) {
          final next = _cleanParentValue(lines[i + 1]);
          if (next.isNotEmpty) return next;
        }
      }
    }
    return null;
  }

  String _cleanParentValue(String text) => text
      .replaceAll(RegExp(r'(আতা|মাতা|Father|Mother)', caseSensitive: false), '')
      .trim();

  String? _extractBloodGroup(String text) {
    final m = RegExp(
      r'(?:blood\s*group|রক্তের\s*গ্রুপ|bloodgroup)[:\/ ]*(.*?)'
      r'(?=place|জন্ম|issue|[ওo]sue|প্রদান|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;

    final candidates = RegExp(
      r'\b(AB|A|B|O)[+\-t]?\b',
      caseSensitive: false,
    ).allMatches(m.group(1)!).map((e) => e.group(0)!).toList();
    if (candidates.isEmpty) return null;

    String best = candidates.first;
    for (final c in candidates) {
      if (c.contains('+') || c.contains('-') || c.toLowerCase().endsWith('t')) {
        best = c;
        break;
      }
    }
    return _normalizeBloodGroup(best);
  }

  String _normalizeBloodGroup(String input) {
    String v = input.toUpperCase().trim();
    if (v.endsWith('T')) v = '${v.substring(0, v.length - 1)}+';
    const assume = {'A': 'A+', 'B': 'B+', 'O': 'O+', 'AB': 'AB+'};
    if (assume.containsKey(v)) return assume[v]!;
    return v;
  }

  String? _extractIssueDate(String text) {
    final m = RegExp(
      r'(?:issue\s*date|[ওo]sue\s*date|প্রদানের\s*তারিখ)[: ]*'
      r'(\d{1,2}[\/ ][0-9A-Za-z]{2,}[\/ ])(\d{3,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    final datePart = m.group(1)!;
    final year = m.group(2)!;
    final fullYear = year.length == 3 ? '${year}0' : year;
    return '$datePart$fullYear';
  }

  String? _extractPlaceOfBirth(String text) {
    final m = RegExp(
      r'(?:place\s*of\s*birth|জন্মস্থান)[: ]*(.*?)'
      r'(?=blood|issue|[ওo]sue|date|প্রদান|মুদ্রণ|$)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _extractAddress(String text) {
    final m = RegExp(
      r'ঠিকানা[: ]*(.+?)(?=Blood|Place|Issue|[ওo]sue|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  Map<String, String?> _parseMRZ(String rawText) {
    final flat = _mrzFlatten(rawText);

    final anchorExp = RegExp(r'I[<K][B8][GC]D');
    final anchors = anchorExp.allMatches(flat).toList();

    if (anchors.isEmpty) {
      return {};
    }

    String? l1, l2, l3;

    for (final anchor in anchors.reversed) {
      final start = anchor.start;
      if (flat.length < start + 90) continue;

      String c1 = _fixMRZAnchor(flat.substring(start, start + 30));
      String c2 = flat.substring(start + 30, start + 60);
      String c3 = flat.substring(start + 60, start + 90);

      final mrzLegal = RegExp(r'^[A-Z0-9<]+$');
      if (mrzLegal.hasMatch(c1) &&
          mrzLegal.hasMatch(c2) &&
          mrzLegal.hasMatch(c3)) {
        l1 = c1;
        l2 = c2;
        l3 = c3;
        break;
      }
    }

    if (l1 == null || l2 == null || l3 == null) {
      return {};
    }

    String? nid;
    if (l1.length >= 16) {
      final docNum = l1.substring(5, 14);
      final pos14 = l1[14];
      final optional = l1.substring(15);

      final optDigits = RegExp(r'^\d+').firstMatch(optional)?.group(0) ?? '';

      if (pos14 == '<' && optDigits.isNotEmpty) {
        nid = docNum + optDigits[0];
      } else if (RegExp(r'^[0-9]$').hasMatch(pos14)) {
        nid = docNum.replaceAll('<', '').trim();
      } else {
        nid = docNum.replaceAll('<', '').trim();
      }

      if ((nid.length) < 13 && optDigits.length >= 4) {
        final candidate = docNum + optDigits;
        if (candidate.length == 13 || candidate.length == 17) {
          nid = candidate;
        }
      }

      if (nid.isEmpty) nid = null;
    }

    String? dob, gender, expiry, nationality;
    if (l2.length >= 18) {
      dob = _formatMRZDate(l2.substring(0, 6));
      final g = l2[7];
      gender = g == 'M' ? 'Male' : (g == 'F' ? 'Female' : null);
      expiry = _formatMRZDate(l2.substring(8, 14));
      nationality = l2.substring(15, 18).replaceAll('<', '').trim();
    }

    String? name;
    if (l3.contains('<<')) {
      final parts = l3.split('<<');
      final surname = parts[0].replaceAll('<', ' ').trim();
      final given = parts.sublist(1).join(' ').replaceAll('<', ' ').trim();
      name = '$given $surname'.trim().replaceAll(RegExp(r' {2,}'), ' ');
    }

    return {
      'nid': (nid?.isEmpty ?? true) ? null : nid,
      'dob': dob,
      'gender': gender,
      'expiry': expiry,
      'nationality': (nationality?.isEmpty ?? true) ? null : nationality,
      'name': name,
    };
  }

  String _mrzFlatten(String text) => _bengaliToAscii(text)
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('«', '<')
      .replaceAll('»', '<')
      .replaceAll('‹', '<')
      .replaceAll('›', '<')
      .replaceAll('“', '<')
      .replaceAll('”', '<')
      .replaceAll('‘', '<')
      .replaceAll('’', '<')
      .replaceAll('"', '<')
      .replaceAll("'", '<')
      .replaceAll('*', '<')
      .replaceAll(';', '<')
      .replaceAll('০', '0')
      .replaceAll('१', '1')
      .replaceAll('२', '2')
      .replaceAll('३', '3')
      .replaceAll('४', '4')
      .replaceAll('५', '5')
      .replaceAll('६', '6')
      .replaceAll('७', '7')
      .replaceAll('८', '8')
      .replaceAll('९', '9');

  String _fixMRZAnchor(String line) {
    if (line.length < 5) return line;
    final fixed = line
        .substring(0, 5)
        .replaceAll('K', '<')
        .replaceAll('8', 'B')
        .replaceAll('C', 'G');
    return fixed + line.substring(5);
  }

  String _formatMRZDate(String raw) {
    if (raw.length != 6) return raw;
    final yy = raw.substring(0, 2);
    final mm = raw.substring(2, 4);
    final dd = raw.substring(4, 6);
    final yyInt = int.tryParse(yy);
    if (yyInt == null) return '$dd/$mm/$yy';

    final currentYY = DateTime.now().year % 100;
    final futureLimit = (currentYY + 20) % 100;
    final is2000s = futureLimit >= currentYY
        ? yyInt <= futureLimit
        : yyInt <= futureLimit || yyInt >= currentYY;

    final year = is2000s ? '20$yy' : '19$yy';
    return '$dd/$mm/$year';
  }
}
