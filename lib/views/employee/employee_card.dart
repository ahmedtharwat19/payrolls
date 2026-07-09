// lib/views/employee/employee_card.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/employee_model.dart';

class EmployeeCard extends StatefulWidget {
  final Employee employee;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<EmployeeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final displayName = employee.getDisplayName(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                employee.isActive ? Colors.green.shade50 : Colors.red.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // ✅ العرض المصغر (دائماً ظاهر)
                // ============================================================
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: employee.isActive 
                          ? Colors.green.shade100 
                          : Colors.red.shade100,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: employee.isActive 
                              ? Colors.green.shade700 
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.work, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  employee.jobTitle.isEmpty ? '-' : employee.jobTitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  employee.department.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ حالة الموظف (مصغرة)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: employee.isActive ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        employee.isActive ? 'active'.tr() : 'inactive'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: employee.isActive ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),

                // ============================================================
                // ✅ العرض الموسع (يظهر عند الضغط)
                // ============================================================
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(height: 0),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // ---- معلومات الراتب (كلها مترجمة) ----
                      _buildInfoRow(
                        icon: Icons.attach_money,
                        label: 'basic_salary'.tr(),
                        value: '${employee.basicSalary.toStringAsFixed(2)} EGP',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.add_circle_outline,
                        label: 'allowances'.tr(),
                        value: '${employee.allowances.toStringAsFixed(2)} EGP',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.remove_circle_outline,
                        label: 'deductions'.tr(),
                        value: '${employee.deductions.toStringAsFixed(2)} EGP',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.monetization_on,
                        label: 'salary_type'.tr(),
                        value: employee.salaryType == 'net' ? 'net'.tr() : 'gross'.tr(),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.payment,
                        label: 'payment_method'.tr(),
                        value: employee.paymentMethod == 'cash' ? 'cash'.tr() : 'bank'.tr(),
                      ),
                      
                      // ---- معلومات إضافية (مترجمة) ----
                      if (employee.bankName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          icon: Icons.account_balance,
                          label: 'bank_name'.tr(),
                          value: employee.bankName,
                        ),
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          icon: Icons.account_balance_wallet,
                          label: 'bank_account'.tr(),
                          value: employee.bankAccount,
                        ),
                      ],

                      // ---- تاريخ ترك الوظيفة (مترجم) ----
                      if (!employee.isActive && employee.resignationDate != null) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          icon: Icons.exit_to_app,
                          label: 'resignation_date'.tr(),
                          value: employee.resignationDate!,
                          color: Colors.red.shade600,
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // ---- أزرار الإجراءات (مترجمة) ----
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.onEdit != null)
                            TextButton.icon(
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text('edit'.tr()),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          if (widget.onDelete != null)
                            TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: const Icon(Icons.delete, size: 18),
                              label: Text('delete'.tr()),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}