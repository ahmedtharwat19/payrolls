class Employee {
  final String id;
  final String name;
  final String nationalId;
  final String department;
  final String jobTitle;
  final String contractType;
  final String employeeType;
  final String hireDate;
  final String insuranceCode;
  final String insuranceFile;
  final String taxFile;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String salaryType; // 'net' or 'gross'
  final String paymentMethod; // 'cash' or 'bank'
  final bool isActive;

  Employee({
    required this.id,
    required this.name,
    required this.nationalId,
    required this.department,
    required this.jobTitle,
    required this.contractType,
    required this.employeeType,
    required this.hireDate,
    required this.insuranceCode,
    required this.insuranceFile,
    required this.taxFile,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.salaryType,
    required this.paymentMethod,
    this.isActive = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'],
    name: json['name'],
    nationalId: json['nationalId'],
    department: json['department'],
    jobTitle: json['jobTitle'],
    contractType: json['contractType'],
    employeeType: json['employeeType'],
    hireDate: json['hireDate'],
    insuranceCode: json['insuranceCode'],
    insuranceFile: json['insuranceFile'],
    taxFile: json['taxFile'],
    basicSalary: (json['basicSalary'] ?? 0).toDouble(),
    allowances: (json['allowances'] ?? 0).toDouble(),
    deductions: (json['deductions'] ?? 0).toDouble(),
    salaryType: json['salaryType'] ?? 'net',
    paymentMethod: json['paymentMethod'] ?? 'cash',
    isActive: json['isActive'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nationalId': nationalId,
    'department': department,
    'jobTitle': jobTitle,
    'contractType': contractType,
    'employeeType': employeeType,
    'hireDate': hireDate,
    'insuranceCode': insuranceCode,
    'insuranceFile': insuranceFile,
    'taxFile': taxFile,
    'basicSalary': basicSalary,
    'allowances': allowances,
    'deductions': deductions,
    'salaryType': salaryType,
    'paymentMethod': paymentMethod,
    'isActive': isActive,
  };

  Employee copyWith({
    String? id,
    String? name,
    String? nationalId,
    String? department,
    String? jobTitle,
    double? basicSalary,
    double? allowances,
    double? deductions,
    String? salaryType,
    String? paymentMethod,
    bool? isActive,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      nationalId: nationalId ?? this.nationalId,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      salaryType: salaryType ?? this.salaryType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      contractType: contractType,
      hireDate: hireDate,
      insuranceCode: insuranceCode,
      insuranceFile: insuranceFile,
      taxFile: taxFile,
      employeeType: employeeType,
      isActive: isActive ?? this.isActive,
    );
  }

  /// 💵 Gross Salary (قبل الخصومات والضرائب)
  double get grossSalary => basicSalary + allowances - deductions;

  /// 📅 عدد أيام الأقدمية
  int get seniorityInDays {
    try {
      final date = DateTime.parse(hireDate);
      return DateTime.now().difference(date).inDays;
    } catch (_) {
      return 0;
    }
  }

  /// 📄 عرض بيانات الموظف كسطر بسيط
  @override
  String toString() {
    return 'Employee($name, $jobTitle, ${grossSalary.toStringAsFixed(2)} EGP)';
  }
}
