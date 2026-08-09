/// Structured fields extracted from a Bangladesh National ID (NID) card.
///
/// Every field is nullable because OCR extraction can fail to locate a given
/// field on a given card (poor lighting, damaged card, OCR misread, etc.) —
/// a `null` field means "not found," not "empty on the card."
///
/// Field set and nullability are ported as-is from Microzen's
/// `NIDCardEntity` (see `docs/ARCHITECTURE.md` §9) — no fields were added or
/// removed during extraction.
class NidCard {
  /// The NID number. Resolved from the MRZ when present, otherwise from the
  /// front-side regex extraction. Valid lengths are 10, 13, or 17 digits.
  final String? nidNumber;

  /// Cardholder's name in Latin/English script.
  final String? name;

  /// Cardholder's name in Bengali script.
  final String? nameLocal;

  /// Date of birth, as extracted (front-side format, e.g. "12 Mar 1990"),
  /// falling back to the MRZ-derived date ("dd/mm/yyyy") when the front-side
  /// extraction fails.
  final String? dateOfBirth;

  /// Father's name (front side).
  final String? fatherName;

  /// Mother's name (front side).
  final String? motherName;

  /// Address (back side).
  final String? address;

  /// Gender, derived only from the MRZ ("Male" / "Female").
  final String? gender;

  /// Card expiry date, derived only from the MRZ ("dd/mm/yyyy").
  final String? expiryDate;

  /// Nationality code, derived only from the MRZ (e.g. "BGD").
  final String? nationality;

  /// Blood group (back side), normalized to include Rh sign (e.g. "A+").
  final String? bloodGroup;

  /// Place of birth (back side).
  final String? placeOfBirth;

  /// Card issue date (back side).
  final String? issueDate;

  const NidCard({
    this.nidNumber,
    this.name,
    this.nameLocal,
    this.dateOfBirth,
    this.fatherName,
    this.motherName,
    this.address,
    this.gender,
    this.expiryDate,
    this.nationality,
    this.bloodGroup,
    this.placeOfBirth,
    this.issueDate,
  });

  @override
  String toString() =>
      'NidCard(nidNumber: $nidNumber, name: $name, nameLocal: $nameLocal, '
      'dateOfBirth: $dateOfBirth, fatherName: $fatherName, '
      'motherName: $motherName, address: $address, gender: $gender, '
      'expiryDate: $expiryDate, nationality: $nationality, '
      'bloodGroup: $bloodGroup, placeOfBirth: $placeOfBirth, '
      'issueDate: $issueDate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NidCard &&
          other.nidNumber == nidNumber &&
          other.name == name &&
          other.nameLocal == nameLocal &&
          other.dateOfBirth == dateOfBirth &&
          other.fatherName == fatherName &&
          other.motherName == motherName &&
          other.address == address &&
          other.gender == gender &&
          other.expiryDate == expiryDate &&
          other.nationality == nationality &&
          other.bloodGroup == bloodGroup &&
          other.placeOfBirth == placeOfBirth &&
          other.issueDate == issueDate;

  @override
  int get hashCode => Object.hash(
    nidNumber,
    name,
    nameLocal,
    dateOfBirth,
    fatherName,
    motherName,
    address,
    gender,
    expiryDate,
    nationality,
    bloodGroup,
    placeOfBirth,
    issueDate,
  );
}
