import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../database/employee_storage.dart';
import '../models/employee_model.dart';

/// استيراد دفعة موظفين مرة واحدة من ملف Excel، بدل ما تضيفهم واحد واحد
/// من الشاشة. ترتيب الأعمدة المتوقع في أول صف (Header) وبعده البيانات:
///
/// name | department | jobTitle | nationalId | hireDate | contractType |
/// employeeType | insuranceCode | basicSalary | allowances | deductions |
/// salaryType | paymentMethod | bankName | bankAccount | bankSwift | bankIban
///
/// أي عمود فاضي بياخد قيمة افتراضية معقولة (متطلبش تملي كله لازم).
class BulkImportService {
  final _employeeStorage = EmployeeStorage();

  Future<BulkImportResult> importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return BulkImportResult(imported: 0, errors: [], cancelled: true);
    }

    final bytes = result.files.single.bytes!;
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null || sheet.maxRows < 2) {
      return BulkImportResult(
        imported: 0,
        errors: [ImportRowError(row: 0, reasonKey: 'import_error_empty_file')],
        cancelled: false,
      );
    }

    int imported = 0;
    final errors = <ImportRowError>[];

    // بنبدأ من الصف التاني (index 1) عشان الصف الأول Header
    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);
      final displayRow = rowIndex + 1;

      try {
        String cell(int i) => (i < row.length ? row[i]?.value?.toString() : null) ?? '';
        double numCell(int i, [double fallback = 0]) {
          final v = cell(i);
          return v.isEmpty ? fallback : (double.tryParse(v) ?? fallback);
        }

        final name = cell(0);
        if (name.isEmpty) {
          errors.add(ImportRowError(row: displayRow, reasonKey: 'import_error_name_required'));
          continue;
        }

        final employee = Employee(
          id: const Uuid().v4(),
          name: name,
          department: cell(1),
          jobTitle: cell(2),
          nationalId: cell(3),
          hireDate: cell(4),
          contractType: cell(5),
          employeeType: cell(6),
          insuranceCode: cell(7),
          insuranceFile: '',
          taxFile: '',
          basicSalary: numCell(8),
          allowances: numCell(9),
          deductions: numCell(10),
          salaryType: cell(11).isEmpty ? 'net' : cell(11),
          paymentMethod: cell(12).isEmpty ? 'cash' : cell(12),
          bankName: cell(13),
          bankAccount: cell(14),
          bankSwift: cell(15),
          bankIban: cell(16),
        );

        await _employeeStorage.insertEmployee(employee);
        imported++;
      } catch (_) {
        errors.add(ImportRowError(row: displayRow, reasonKey: 'import_error_invalid_row'));
      }
    }

    return BulkImportResult(imported: imported, errors: errors, cancelled: false);
  }
}

class ImportRowError {
  final int row;
  final String reasonKey; // مفتاح ترجمة
  const ImportRowError({required this.row, required this.reasonKey});
}

class BulkImportResult {
  final int imported;
  final List<ImportRowError> errors;
  final bool cancelled;
  const BulkImportResult({required this.imported, required this.errors, required this.cancelled});
}
