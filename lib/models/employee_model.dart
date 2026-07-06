// lib/models/employee_model.dart

class Employee {
  final String id;
  final String name;
  final String department;
  final String jobTitle;
  final String nationalId;
  final String hireDate;
  final String contractType;
  final String employeeType;
  final String insuranceCode;
  final String insuranceFile;
  final String taxFile;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String salaryType; // 'net' or 'gross'
  final String paymentMethod; // 'cash' or 'bank'
  final bool isActive;

  final String bankName;
  final String bankAccount;
  final String bankSwift;
  final String bankIban;

  Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.jobTitle,
    required this.nationalId,
    required this.hireDate,
    required this.contractType,
    required this.employeeType,
    required this.insuranceCode,
    required this.insuranceFile,
    required this.taxFile,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.salaryType,
    required this.paymentMethod,
    this.isActive = true,
    this.bankName = '',
    this.bankAccount = '',
    this.bankSwift = '',
    this.bankIban = '',
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      name: map['name'] as String,
      department: map['department'] as String,
      jobTitle: map['jobTitle'] as String,
      nationalId: map['nationalId'] as String,
      hireDate: map['hireDate'] as String,
      contractType: map['contractType'] as String,
      employeeType: map['employeeType'] as String,
      insuranceCode: map['insuranceCode'] as String,
      insuranceFile: map['insuranceFile'] as String,
      taxFile: map['taxFile'] as String,
      basicSalary: (map['basicSalary'] as num).toDouble(),
      allowances: (map['allowances'] as num).toDouble(),
      deductions: (map['deductions'] as num).toDouble(),
      salaryType: map['salaryType'] as String,
      paymentMethod: map['paymentMethod'] as String,
      isActive: (map['isActive'] as int) == 1,
      bankName: map['bankName'] as String? ?? '',
      bankAccount: map['bankAccount'] as String? ?? '',
      bankSwift: map['bankSwift'] as String? ?? '',
      bankIban: map['bankIban'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'jobTitle': jobTitle,
      'nationalId': nationalId,
      'hireDate': hireDate,
      'contractType': contractType,
      'employeeType': employeeType,
      'insuranceCode': insuranceCode,
      'insuranceFile': insuranceFile,
      'taxFile': taxFile,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'salaryType': salaryType,
      'paymentMethod': paymentMethod,
      'isActive': isActive ? 1 : 0,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'bankSwift': bankSwift,
      'bankIban': bankIban,
    };
  }

  Employee copyWith({
    String? id,
    String? name,
    String? department,
    String? jobTitle,
    String? nationalId,
    String? hireDate,
    String? contractType,
    String? employeeType,
    String? insuranceCode,
    String? insuranceFile,
    String? taxFile,
    double? basicSalary,
    double? allowances,
    double? deductions,
    String? salaryType,
    String? paymentMethod,
    bool? isActive,
    String? bankName,
    String? bankAccount,
    String? bankSwift,
    String? bankIban,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      nationalId: nationalId ?? this.nationalId,
      hireDate: hireDate ?? this.hireDate,
      contractType: contractType ?? this.contractType,
      employeeType: employeeType ?? this.employeeType,
      insuranceCode: insuranceCode ?? this.insuranceCode,
      insuranceFile: insuranceFile ?? this.insuranceFile,
      taxFile: taxFile ?? this.taxFile,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      salaryType: salaryType ?? this.salaryType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isActive: isActive ?? this.isActive,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bankSwift: bankSwift ?? this.bankSwift,
      bankIban: bankIban ?? this.bankIban,
    );
  }
}