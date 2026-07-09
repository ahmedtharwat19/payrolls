// lib/views/employee/employee_form.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/employee_model.dart';
import '../../controllers/employee_controller.dart';
import '../shared/section_header.dart';
import 'package:uuid/uuid.dart';

class EmployeeForm extends StatefulWidget {
  final Employee? employee;
  const EmployeeForm({super.key, this.employee});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _data = <String, dynamic>{};

  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankSwiftController = TextEditingController();
  final _bankIbanController = TextEditingController();

  // ✅ قائمة الأقسام - مفاتيح (تُستخدم للتخزين)
  final List<String> _departments = [
    'hr',
    'it',
    'finance',
    'sales',
    'marketing',
    'operations',
    'logistics',
    'quality',
    'maintenance',
    'purchasing',
  ];

  final List<String> _contractTypes = ['permanent', 'temporary', 'contract'];
  final List<String> _employeeTypes = ['full-time', 'part-time', 'intern'];

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _loadEmployeeData(widget.employee!);
    } else {
      // قيم افتراضية
      _data['department'] = _departments.first;
      _data['contractType'] = _contractTypes.first;
      _data['employeeType'] = _employeeTypes.first;
      _data['salaryType'] = 'net';
      _data['paymentMethod'] = 'cash';
      _data['basicSalary'] = 0.0;
      _data['allowances'] = 0.0;
      _data['deductions'] = 0.0;
      _data['isActive'] = true;
    }
  }

  void _loadEmployeeData(Employee emp) {
    _data['nameAr'] = emp.nameAr;
    _data['nameEn'] = emp.nameEn;
    _data['department'] = _departments.contains(emp.department)
        ? emp.department
        : _departments.first;
    _data['jobTitle'] = emp.jobTitle;
    _data['nationalId'] = emp.nationalId;
    _data['hireDate'] = emp.hireDate;
    _data['resignationDate'] = emp.resignationDate;
    _data['contractType'] = _contractTypes.contains(emp.contractType)
        ? emp.contractType
        : _contractTypes.first;
    _data['employeeType'] = _employeeTypes.contains(emp.employeeType)
        ? emp.employeeType
        : _employeeTypes.first;
    _data['insuranceCode'] = emp.insuranceCode;
    _data['basicSalary'] = emp.basicSalary;
    _data['allowances'] = emp.allowances;
    _data['deductions'] = emp.deductions;
    _data['salaryType'] = emp.salaryType;
    _data['paymentMethod'] = emp.paymentMethod;
    _data['bankName'] = emp.bankName;
    _data['bankAccount'] = emp.bankAccount;
    _data['bankSwift'] = emp.bankSwift;
    _data['bankIban'] = emp.bankIban;
    _data['isActive'] = emp.isActive;

    _bankNameController.text = emp.bankName;
    _bankAccountController.text = emp.bankAccount;
    _bankSwiftController.text = emp.bankSwift;
    _bankIbanController.text = emp.bankIban;
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankSwiftController.dispose();
    _bankIbanController.dispose();
    super.dispose();
  }

  /// التحقق من اللغة العربية
  bool get _isArabic => context.locale.languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmployeeController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employee == null ? 'add_employee'.tr() : 'edit_employee'.tr(),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ============================================================
              // 1. المعلومات الأساسية
              // ============================================================
              const SectionHeader(title: 'basic_info'),
              const SizedBox(height: 8),

              // ✅ الاسم بالعربية
              TextFormField(
                initialValue: _data['nameAr']?.toString(),
                decoration: InputDecoration(
                  labelText: _isArabic ? 'الاسم (عربي)' : 'Name (Arabic)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'name_required'.tr() : null,
                onSaved: (v) => _data['nameAr'] = v,
              ),
              const SizedBox(height: 12),

              // ✅ الاسم بالإنجليزية
              TextFormField(
                initialValue: _data['nameEn']?.toString(),
                decoration: InputDecoration(
                  labelText: _isArabic ? 'الاسم (إنجليزي)' : 'Name (English)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onSaved: (v) => _data['nameEn'] = v,
              ),
              const SizedBox(height: 12),

              // ✅ Dropdown للأقسام
              DropdownButtonFormField<String>(
                initialValue: _data['department'] ?? _departments.first,
                decoration: InputDecoration(
                  labelText: 'department'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.business),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem<String>(
                    value: dept,
                    child: Text(dept.tr()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _data['department'] = v),
                onSaved: (v) => _data['department'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                initialValue: _data['jobTitle']?.toString(),
                decoration: InputDecoration(
                  labelText: 'job_title'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.work),
                ),
                onSaved: (v) => _data['jobTitle'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                initialValue: _data['nationalId']?.toString(),
                decoration: InputDecoration(
                  labelText: 'national_id'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.badge),
                ),
                onSaved: (v) => _data['nationalId'] = v,
              ),
              const SizedBox(height: 12),

              // ✅ تاريخ التعيين
              TextFormField(
                initialValue: _data['hireDate']?.toString() ?? '',
                decoration: InputDecoration(
                  labelText: 'hire_date'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _data['hireDate'] = date.toIso8601String());
                      }
                    },
                  ),
                ),
                onSaved: (v) => _data['hireDate'] = v ?? DateTime.now().toIso8601String(),
              ),
              const SizedBox(height: 12),

              // ✅ حالة الموظف (نشط / غير نشط)
              DropdownButtonFormField<bool>(
                initialValue: _data['isActive'] ?? true,
                decoration: InputDecoration(
                  labelText: 'status'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.circle),
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Active')),
                  DropdownMenuItem(value: false, child: Text('Inactive')),
                ],
                onChanged: (v) => setState(() => _data['isActive'] = v),
                onSaved: (v) => _data['isActive'] = v,
              ),
              const SizedBox(height: 12),

              // ✅ تاريخ ترك الوظيفة (يظهر فقط عند isActive = false)
              if (_data['isActive'] == false) ...[
                TextFormField(
                  initialValue: _data['resignationDate']?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: 'resignation_date'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.exit_to_app),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _data['resignationDate'] = date.toIso8601String());
                        }
                      },
                    ),
                  ),
                  onSaved: (v) => _data['resignationDate'] = v,
                ),
                const SizedBox(height: 12),
              ],

              // ============================================================
              // 2. معلومات الراتب
              // ============================================================
              const SectionHeader(title: 'salary_info'),
              const SizedBox(height: 8),

              TextFormField(
                initialValue: _data['basicSalary']?.toString() ?? '0',
                decoration: InputDecoration(
                  labelText: 'basic_salary'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'salary_required'.tr();
                  if (double.tryParse(v!) == null) return 'invalid_number'.tr();
                  return null;
                },
                onSaved: (v) => _data['basicSalary'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              TextFormField(
                initialValue: _data['allowances']?.toString() ?? '0',
                decoration: InputDecoration(
                  labelText: 'allowances'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['allowances'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              TextFormField(
                initialValue: _data['deductions']?.toString() ?? '0',
                decoration: InputDecoration(
                  labelText: 'deductions'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.remove_circle_outline),
                  prefixText: 'EGP ',
                ),
                keyboardType: TextInputType.number,
                onSaved: (v) => _data['deductions'] = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _data['salaryType'] ?? 'net',
                decoration: InputDecoration(
                  labelText: 'salary_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.monetization_on),
                ),
                items: ['net', 'gross'].map((e) {
                  return DropdownMenuItem<String>(
                    value: e,
                    child: Text(e == 'net' ? 'net'.tr() : 'gross'.tr()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _data['salaryType'] = v),
                onSaved: (v) => _data['salaryType'] = v,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _data['paymentMethod'] ?? 'cash',
                decoration: InputDecoration(
                  labelText: 'payment_method'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.payment),
                ),
                items: ['cash', 'bank'].map((e) {
                  return DropdownMenuItem<String>(
                    value: e,
                    child: Text(e == 'cash' ? 'cash'.tr() : 'bank'.tr()),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _data['paymentMethod'] = v);
                },
                onSaved: (v) => _data['paymentMethod'] = v,
              ),
              const SizedBox(height: 16),

              // ============================================================
              // 3. بيانات البنك (تظهر عند اختيار "بنك")
              // ============================================================
              if (_data['paymentMethod'] == 'bank') ...[
                const SectionHeader(title: 'bank_details'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'bank_name'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance),
                  ),
                  onChanged: (v) => _data['bankName'] = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankAccountController,
                  decoration: InputDecoration(
                    labelText: 'bank_account'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  onChanged: (v) => _data['bankAccount'] = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankSwiftController,
                  decoration: InputDecoration(
                    labelText: 'bank_swift'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.code),
                  ),
                  onChanged: (v) => _data['bankSwift'] = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankIbanController,
                  decoration: InputDecoration(
                    labelText: 'bank_iban'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  onChanged: (v) => _data['bankIban'] = v,
                ),
                const SizedBox(height: 16),
              ],

              // ============================================================
              // 4. معلومات إضافية
              // ============================================================
              const SectionHeader(title: 'additional_info'),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _data['contractType'] ?? _contractTypes.first,
                decoration: InputDecoration(
                  labelText: 'contract_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description),
                ),
                items: _contractTypes.map((e) {
                  return DropdownMenuItem<String>(
                    value: e,
                    child: Text(e.tr()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _data['contractType'] = v),
                onSaved: (v) => _data['contractType'] = v,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _data['employeeType'] ?? _employeeTypes.first,
                decoration: InputDecoration(
                  labelText: 'employee_type'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.people),
                ),
                items: _employeeTypes.map((e) {
                  return DropdownMenuItem<String>(
                    value: e,
                    child: Text(e.tr()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _data['employeeType'] = v),
                onSaved: (v) => _data['employeeType'] = v,
              ),
              const SizedBox(height: 12),

              TextFormField(
                initialValue: _data['insuranceCode']?.toString(),
                decoration: InputDecoration(
                  labelText: 'insurance_code'.tr(),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.health_and_safety),
                ),
                onSaved: (v) => _data['insuranceCode'] = v ?? '',
              ),
              const SizedBox(height: 20),

              // ============================================================
              // 5. أزرار الحفظ والإلغاء
              // ============================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          _saveEmployee(controller);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('save'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveEmployee(EmployeeController controller) {
    final employee = Employee(
      id: widget.employee?.id ?? const Uuid().v4(),
      nameAr: _data['nameAr'] ?? '',
      nameEn: _data['nameEn'] ?? '',
      department: _data['department'] ?? '',
      jobTitle: _data['jobTitle'] ?? '',
      nationalId: _data['nationalId'] ?? '',
      hireDate: _data['hireDate'] ?? DateTime.now().toIso8601String(),
      resignationDate: _data['resignationDate'],
      contractType: _data['contractType'] ?? 'permanent',
      employeeType: _data['employeeType'] ?? 'full-time',
      insuranceCode: _data['insuranceCode'] ?? '',
      insuranceFile: widget.employee?.insuranceFile ?? '',
      taxFile: widget.employee?.taxFile ?? '',
      basicSalary: _data['basicSalary'] ?? 0.0,
      allowances: _data['allowances'] ?? 0.0,
      deductions: _data['deductions'] ?? 0.0,
      salaryType: _data['salaryType'] ?? 'net',
      paymentMethod: _data['paymentMethod'] ?? 'cash',
      bankName: _data['bankName'] ?? '',
      bankAccount: _data['bankAccount'] ?? '',
      bankSwift: _data['bankSwift'] ?? '',
      bankIban: _data['bankIban'] ?? '',
      isActive: _data['isActive'] ?? true,
    );

    if (widget.employee == null) {
      controller.addEmployee(employee);
    } else {
      controller.updateEmployee(employee);
    }

    Navigator.pop(context);
  }
}