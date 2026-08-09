// Parser regression tests for NidScanParser.
//
// The original source implementation's test suite only covered its
// orchestration and barcode decoding — it had no dedicated coverage of the
// regex/MRZ field-extraction methods themselves. Two barcode-format cases
// are ported verbatim below (see the 'barcode parsing' group); everything
// else here is new coverage, exercising the ported _normalize/_extract*/
// _parseMRZ* logic directly — with no behavior change from the source.
//
// IMPORTANT finding surfaced while writing these tests (flagged, not
// "fixed" — see the "single-line collapse" group below): `_normalize`
// collapses ALL whitespace, including newlines, to single spaces *before*
// `_lines()` ever splits on '\n'. So `frontLines`/`backLines` are always a
// single-element list in practice — every "look at the next line" or
// "lines seen so far" branch in `_extractNames`/`_extractParent` is
// unreachable dead code given how the two methods are actually composed in
// `parse()`. This was true of the original implementation as well (ported
// verbatim, not introduced here) — it is not something this extraction
// changed, but it materially affects what inputs actually exercise which
// code path, so tests below are written against the real (single-line)
// behavior rather than the apparently-intended (multi-line) one.

import 'package:flutter_test/flutter_test.dart';
import 'package:bd_nid_ocr/bd_nid_ocr.dart';

void main() {
  const parser = NidScanParser();

  group('name extraction', () {
    test('extracts English name via "Name:" label', () {
      final card = parser.parse(
        frontText: 'Name: John Doe\nDate of Birth: 12 Mar 1990',
        backText: '',
      );
      expect(card.name, 'John Doe');
    });

    test(
      'extracts English name after a bare "Name" label once the line is '
      'joined by normalization (an inline match, not the "next line" '
      'fallback branch — see the file-level note on single-line collapse)',
      () {
        final card = parser.parse(
          frontText: 'Name\nJohn Doe\nDate of Birth: 12 Mar 1990',
          backText: '',
        );
        expect(card.name, 'John Doe');
      },
    );

    test('falls back to an all-caps line when no "Name:" label is found — '
        'only reachable when the front text is the bare name with none of '
        'the boilerplate skip-words (GOVERNMENT/NATIONAL/BANGLADESH/...), '
        'since normalization joins the whole front side into one line', () {
      final card = parser.parse(frontText: 'JOHN ROBERT DOE', backText: '');
      expect(card.name, 'JOHN ROBERT DOE');
    });

    test(
      'extracts Bengali name via "নাম:" label and strips non-Bengali trailing text',
      () {
        final card = parser.parse(
          frontText: 'নাম: জন ডো Name: John Doe',
          backText: '',
        );
        expect(card.nameLocal, 'জন ডো');
      },
    );

    test('detects a standalone pure-Bengali line only when the front text is '
        'nothing but that name (any Latin/digit content anywhere in the '
        'front side fails the whole-line ^[bengali|space]+\$ check, per the '
        'single-line-collapse note above)', () {
      final pureBengaliOnly = parser.parse(
        frontText: 'জন ডো রহমান',
        backText: '',
      );
      expect(pureBengaliOnly.nameLocal, 'জন ডো রহমান');

      final mixedWithLatin = parser.parse(
        frontText: 'জন ডো রহমান\nDate of Birth: 12 Mar 1990',
        backText: '',
      );
      expect(mixedWithLatin.nameLocal, isNull);
    });

    test("the পিতা/Father-line guard in _extractNames (skip the pure-Bengali "
        'heuristic if a পিতা/Father line already appeared) is unreachable '
        'dead code: `lines.sublist(0, i)` is always empty because `lines` '
        'is always length 1 (see the file-level single-line-collapse note) '
        '— ported as-is from the source, not exercised here as "working" '
        'multi-line logic', () {
      // "পিতা" appears in the same (single, joined) line as the name —
      // the guard's sublist(0, i) is empty (i == 0), so it never sees a
      // prior পিতা line to guard against, and the whole-line pure-Bengali
      // check fails anyway because "পিতা:" contains a non-Bengali colon.
      final card = parser.parse(
        frontText: 'পিতা: রহিম উদ্দিন\nজন ডো রহমান',
        backText: '',
      );
      expect(card.nameLocal, isNull);
    });
  });

  group('date of birth extraction', () {
    test('extracts a "D Mon YYYY" style date from the front side', () {
      final card = parser.parse(
        frontText: 'Name: John Doe\nDate of Birth: 5 Jan 1995',
        backText: '',
      );
      expect(card.dateOfBirth, '5 Jan 1995');
    });

    test('is null when no date pattern is present', () {
      final card = parser.parse(frontText: 'Name: John Doe', backText: '');
      expect(card.dateOfBirth, isNull);
    });
  });

  group('NID number extraction', () {
    // _extractNID's regex caps each whitespace-separated digit run at 5
    // digits (\d{3,5}), so fixtures below group digits accordingly —
    // matching how the source expects OCR'd NID numbers to be chunked.
    test('accepts a 10-digit NID split as 3+3+4', () {
      final card = parser.parse(
        frontText: 'NID No: 123 456 7890',
        backText: '',
      );
      expect(card.nidNumber, '1234567890');
    });

    test('accepts a 13-digit NID split as 3+5+5', () {
      final card = parser.parse(
        frontText: 'NID No: 123 45678 90123',
        backText: '',
      );
      expect(card.nidNumber, '1234567890123');
      expect(card.nidNumber!.length, 13);
    });

    test('accepts a 17-digit NID split as 5+4+4+4', () {
      final card = parser.parse(
        frontText: 'NID No: 12345 6789 0123 4567',
        backText: '',
      );
      expect(card.nidNumber, '12345678901234567');
      expect(card.nidNumber!.length, 17);
    });

    test('rejects a digit run that matches none of {10, 13, 17}', () {
      final card = parser.parse(frontText: 'Ref: 123 456', backText: '');
      expect(card.nidNumber, isNull);
    });

    test('converts Bengali digits to ASCII before matching', () {
      // ০=0 ১=1 ২=2 ৩=3 ৪=4 ৫=5 ৬=6 ৭=7 ৮=8 ৯=9
      final card = parser.parse(
        frontText: 'NID No: ১২৩ ৪৫৬ ৭৮৯০',
        backText: '',
      );
      expect(card.nidNumber, '1234567890');
    });
  });

  group('parent name extraction', () {
    test('extracts father and mother names by Bengali label', () {
      final card = parser.parse(
        frontText: 'পিতা: রহিম উদ্দিন\nমাতা: রহিমা বেগম',
        backText: '',
      );
      expect(card.fatherName, 'রহিম উদ্দিন');
      expect(card.motherName, 'রহিমা বেগম');
    });

    test('extracts father name by English label', () {
      final card = parser.parse(
        frontText: 'Father: Abdul Karim\nMother: Fatima Begum',
        backText: '',
      );
      expect(card.fatherName, 'Abdul Karim');
      expect(card.motherName, 'Fatima Begum');
    });

    test('extracts the value for a bare label via the inline regex once '
        'normalization has joined the label and value onto one line', () {
      final card = parser.parse(frontText: 'Father\nAbdul Karim', backText: '');
      expect(card.fatherName, 'Abdul Karim');
    });
  });

  group('blood group extraction', () {
    test('extracts a blood group with an explicit sign', () {
      final card = parser.parse(frontText: '', backText: 'Blood Group: A+');
      expect(card.bloodGroup, 'A+');
    });

    test('assumes a positive sign when the OCR text has no sign at all', () {
      // _normalizeBloodGroup's `assume` map: bare A/B/O/AB default to "+".
      final card = parser.parse(frontText: '', backText: 'Blood Group: O');
      expect(card.bloodGroup, 'O+');
    });

    test('corrects a common OCR misread of "Blood Group"', () {
      // Blo+[co]+\s*Group needs >=1 extra 'o' *and* >=1 more [c|o] char
      // after the literal "Blo" — "Blooc" (Blo + o + c) is the minimal
      // misread this regex repairs. Expected result is 'B+', not 'B-' —
      // see the dedicated test below for why.
      final card = parser.parse(frontText: '', backText: 'Blooc Group: B-');
      expect(card.bloodGroup, 'B+');
    });

    test('FINDING: a "-" sign is dropped by the candidate regex whenever it '
        'is followed by whitespace or end-of-string, so a negative blood '
        'group is (unintentionally, but faithfully-ported) unreachable in '
        'practice — `\\b(AB|A|B|O)[+\\-t]?\\b` requires a word character on '
        'the far side of the sign for `\\b` to hold after consuming it '
        '(e.g. "B-1" keeps the sign; "B-" or "B- " does not), and '
        '`_normalizeBloodGroup` then defaults the signless letter to "+". '
        'Flagged per Rule 7 (record, don\'t silently fix) — not something '
        'this extraction changed, the source has the same regex.', () {
      final negativeSignDropped = parser.parse(
        frontText: '',
        backText: 'Blood Group: AB-',
      );
      expect(negativeSignDropped.bloodGroup, 'AB+');

      final signKeptOnlyWithNoSeparatorBeforeAWordChar = parser.parse(
        frontText: '',
        backText: 'Blood Group: B-1',
      );
      expect(signKeptOnlyWithNoSeparatorBeforeAWordChar.bloodGroup, 'B-');
    });

    test('is null when no recognizable blood group token is present', () {
      final card = parser.parse(frontText: '', backText: 'Blood Group:');
      expect(card.bloodGroup, isNull);
    });
  });

  group('issue date extraction', () {
    test('extracts and pads a 3-digit year to 4 digits', () {
      final card = parser.parse(
        frontText: '',
        backText: 'Issue Date: 12/Jan/199',
      );
      expect(card.issueDate, '12/Jan/1990');
    });

    test('extracts a well-formed issue date as-is', () {
      final card = parser.parse(
        frontText: '',
        backText: 'Issue Date: 01/Feb/2015',
      );
      expect(card.issueDate, '01/Feb/2015');
    });
  });

  group('place of birth extraction', () {
    test('extracts text up to the next section label', () {
      final card = parser.parse(
        frontText: '',
        backText: 'Place of Birth: Dhaka Blood Group: A+',
      );
      expect(card.placeOfBirth, 'Dhaka');
    });
  });

  group('address extraction', () {
    test('extracts Bengali address text up to the next section label', () {
      final card = parser.parse(
        frontText: '',
        backText: 'ঠিকানা: ঢাকা, বাংলাদেশ Blood Group: A+',
      );
      expect(card.address, 'ঢাকা, বাংলাদেশ');
    });
  });

  group('MRZ parsing', () {
    // A hand-built, exactly-90-char TD1-shaped MRZ (3 x 30 chars), anchored
    // on "I<BGD". _mrzFlatten strips all whitespace before slicing, so
    // these three conceptual lines must each be *exactly* 30 characters —
    // the '\n's below are cosmetic only (stripped before anchor-matching).
    //
    // L1 "I<BGD123456789<012345678901234":
    //   I<BGD(5) + docNum "123456789"(9) + pos14 "<"(1) + optional
    //   "012345678901234"(15) = 30. pos14=='<' and optional starts with a
    //   digit => nid = docNum + optDigits[0] = "1234567890" (10 digits).
    // L2 "9001019M3001015BGD<<<<<<<<<<<<":
    //   dob "900101"(6) + check "9"(1) + sex "M"(1) + expiry "300101"(6) +
    //   check "5"(1) + nationality "BGD"(3) + filler(12) = 30.
    // L3 "DOE<<JOHN<ROBERT<<<<<<<<<<<<<<": surname<<given, 30 chars.
    const l1 = 'I<BGD123456789<012345678901234';
    const l2 = '9001019M3001015BGD<<<<<<<<<<<<';
    const l3 = 'DOE<<JOHN<ROBERT<<<<<<<<<<<<<<';
    final mrzBlock = '$l1\n$l2\n$l3';

    test('extracts the NID number from the document-number field', () {
      final card = parser.parse(frontText: '', backText: mrzBlock);
      expect(card.nidNumber, '1234567890');
    });

    test('extracts date of birth, gender, expiry, and nationality', () {
      final card = parser.parse(frontText: '', backText: mrzBlock);
      expect(card.dateOfBirth, '01/01/1990');
      expect(card.gender, 'Male');
      expect(card.expiryDate, '01/01/2030');
      expect(card.nationality, 'BGD');
    });

    test('extracts a name from the "surname<<given" MRZ line', () {
      final card = parser.parse(frontText: '', backText: mrzBlock);
      expect(card.name, 'JOHN ROBERT DOE');
    });

    test('nidNumber precedence is MRZ-first (`mrz[\'nid\'] ?? frontNid`), but '
        'name/dateOfBirth precedence is front-first (`front ?? mrz[...]`) — '
        'the two are NOT symmetric, contrary to a "MRZ wins where both exist" '
        'summary one might assume from the class doc comment; that summary is '
        'imprecise for name/dateOfBirth specifically, per the actual '
        'field-by-field `parse()` code. Flagged here, not silently corrected '
        '(the behavior itself is unchanged from the source it was ported '
        'from).', () {
      final card = parser.parse(
        frontText: 'NID No: 999 999 9999\nName: Front Side Name',
        backText: mrzBlock,
      );
      // nidNumber: MRZ's non-null value wins over the front regex match.
      expect(card.nidNumber, '1234567890');
      // name: the front regex match wins over the MRZ name — but
      // _trimAtBoundary then cuts the captured value at the embedded
      // "Name" substring inside "Side Name", so the real output is
      // "Front Side", not the naively-expected "Front Side Name".
      expect(card.name, 'Front Side');
    });

    test('returns no MRZ fields when the I<BGD anchor is absent', () {
      final card = parser.parse(
        frontText: '',
        backText: 'some unrelated back-of-card text with no MRZ at all',
      );
      expect(card.gender, isNull);
      expect(card.expiryDate, isNull);
      expect(card.nationality, isNull);
    });

    test('tolerates common OCR anchor misreads (I<BGD misread as IK8CD — '
        'each of <,B,G individually misread as K,8,C, same length so the '
        '30-char slicing stays aligned)', () {
      final fuzzyBlock = mrzBlock.replaceFirst('I<BGD', 'IK8CD');
      final card = parser.parse(frontText: '', backText: fuzzyBlock);
      expect(card.gender, 'Male');
      expect(card.nidNumber, '1234567890');
    });
  });

  group('barcode parsing', () {
    test('decodes the XML-tagged format', () {
      final data = parser.parseBarcode(
        '<pin>1234567890123</pin><name>John Doe</name><DOB>01-01-1990</DOB>',
      );
      expect(data['ID Number'], '1234567890123');
      expect(data['Full Name'], 'John Doe');
      expect(data['Date of Birth'], '01-01-1990');
    });

    test('decodes the control-character-delimited format', () {
      // 0x1D (Group Separator) delimits fields; 0x04 is stripped from
      // values. Ported as-is from the source's unverified "delimited
      // key-value" branch (see NidScanParser.parseBarcode).
      const gs = '\x1d';
      const eot = '\x04';
      final raw =
          'NM$eot'
          'John Doe$gs'
          'NW$eot'
          '1234567890123$gs'
          'BR$eot'
          '01-01-1990';

      final data = parser.parseBarcode(raw);

      expect(data['Full Name'], 'John Doe');
      expect(data['ID Number'], '1234567890123');
      expect(data['Date of Birth'], '01-01-1990');
    });

    test('returns an empty map for unrecognized payloads', () {
      expect(parser.parseBarcode('not a recognized format'), isEmpty);
    });
  });

  group('missing/malformed input', () {
    test('returns an all-null NidCard for empty input', () {
      final card = parser.parse(frontText: '', backText: '');
      expect(card.nidNumber, isNull);
      expect(card.name, isNull);
      expect(card.nameLocal, isNull);
      expect(card.dateOfBirth, isNull);
      expect(card.fatherName, isNull);
      expect(card.motherName, isNull);
      expect(card.address, isNull);
      expect(card.gender, isNull);
      expect(card.expiryDate, isNull);
      expect(card.nationality, isNull);
      expect(card.bloodGroup, isNull);
      expect(card.placeOfBirth, isNull);
      expect(card.issueDate, isNull);
    });

    test('does not throw on garbled/malformed OCR text', () {
      expect(
        () => parser.parse(
          frontText: '@#\$%^&&**  \n\n\t\t###???',
          backText: '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
        ),
        returnsNormally,
      );
    });
  });
}
