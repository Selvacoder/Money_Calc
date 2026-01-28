import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/item.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import 'category_dialog.dart';

class AddItemDialog extends StatefulWidget {
  final Category? category; // Pre-selected category
  final Item? editingItem; // Item to edit
  final Item?
  existingItem; // Item to add transaction from (One-Time mode equivalent)
  final bool isDaily; // Default frequency
  final bool initialIsVariable; // Default to variable mode

  const AddItemDialog({
    super.key,
    this.category,
    this.editingItem,
    this.existingItem,
    this.isDaily = true,
    this.initialIsVariable = false,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late bool _isDaily;
  late bool _isExpense;
  String? _selectedCategoryId;
  String _selectedIcon = 'star';
  int? _dueDay;
  bool _isVariable = false;

  final List<String> iconOptions = [
    'star',
    'shopping_cart',
    'restaurant',
    'commute',
    'home',
    'medical_services',
    'school',
    'fitness_center',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem ?? widget.existingItem;

    _titleController = TextEditingController(text: item?.title);
    _amountController = TextEditingController(
      text: item != null
          ? (item.amount.toStringAsFixed(
              item.amount.truncateToDouble() == item.amount ? 0 : 2,
            ))
          : '',
    );

    if (widget.editingItem != null) {
      // Editing Mode
      _isVariable = widget.editingItem!.isVariable ?? false;
      // Initialize _isDaily logic: Daily if frequency is daily, OR if variable but no dueDay (default)
      // If it has a DueDay, we treat it as "Monthly" UI-wise
      if (_isVariable) {
        _isDaily = widget.editingItem?.dueDay == null;
      } else {
        _isDaily = widget.editingItem?.frequency == 'daily';
      }
    } else if (widget.existingItem != null) {
      // Add Transaction Mode (from existing item)
      _isDaily = widget.existingItem?.frequency == 'daily'; // inherited
      _isVariable = false;
    } else {
      // Add New Mode
      _isDaily = widget.isDaily;
      _isVariable = widget.initialIsVariable;
    }

    // Restore missing initialization
    _selectedCategoryId = item?.categoryId ?? widget.category?.id;

    if (item != null) {
      _isExpense = item.isExpense;
    } else if (widget.category != null) {
      _isExpense = widget.category!.type == 'expense';
    } else {
      _isExpense = true;
    }

    _dueDay = item?.dueDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final categories = provider.categories;

    // Dropdown Items
    final List<DropdownMenuItem<String>> dropdownItems = categories
        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
        .toList();

    dropdownItems.add(
      const DropdownMenuItem(value: 'other_virtual', child: Text('Other')),
    );

    dropdownItems.add(
      DropdownMenuItem(
        value: 'new_category',
        child: Text(
          '+ New Category',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Auto-select logic moved to safe place or handled via fallback in value
    // But Dropdown value must match item.
    // If _selectedCategoryId is null, we can try to find a valid one to Display, but strictly we should set the state.
    // However, since categories update via provider, we can just ensure value is valid.

    String? effectiveCategoryId = _selectedCategoryId;
    if (effectiveCategoryId == null && categories.isNotEmpty) {
      final others = categories
          .where((c) => c.name.toLowerCase().contains('other'))
          .firstOrNull;
      effectiveCategoryId = others?.id ?? categories.first.id;
      // We don't setState here to avoid rebuild loop, but we use this value for the Dropdown
      // But if user picks something else, _selectedCategoryId updates.
      // We should ideally update _selectedCategoryId in the future, possibly in a post-frame callback if we want persistence,
      // but for rendering the dropdown default, using a local var is safest.
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Toggle (Quick Entry / One Time) - Only if NOT editing
              if (widget.editingItem == null) ...[
                _buildModeToggle(context),
                const SizedBox(height: 24),
              ],

              Text(
                widget.editingItem != null
                    ? (_isVariable ? 'Edit Variable Entry' : 'Edit Quick Entry')
                    : (_isVariable ? 'New Variable Entry' : 'New Quick Entry'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: effectiveCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: dropdownItems,
                onChanged: (value) async {
                  if (value == 'new_category') {
                    // Open Category Dialog on top
                    await showDialog(
                      context: context,
                      builder: (context) => const CategoryDialog(),
                    );

                    // After closing CategoryDialog, reset selection to null so user can pick
                    // or we could listen to the result if CategoryDialog returned the new ID.
                    setState(() {
                      _selectedCategoryId =
                          null; // Let effective logic handle default or wait for user
                    });
                  } else {
                    setState(() {
                      _selectedCategoryId = value;
                      if (value != null && value != 'other_virtual') {
                        final cat = categories.firstWhere(
                          (c) => c.id == value,
                          orElse: () => categories.first,
                        );
                        _isExpense = cat.type == 'expense';
                        // Also update icon if it matches category default?
                        // Maybe not enforce it if user picked one.
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Icon Selector (Always show now, or logic specific?)
              // User said "it like must be in the colour of yellow", but we still need an icon.
              const SizedBox(height: 16),
              _buildIconSelector(context),
              const SizedBox(height: 16),

              // Expense/Income Toggle (Only for Other/Virtual)
              if (_shouldShowTypeToggle(categories)) ...[
                _buildTypeToggle(context),
                const SizedBox(height: 16),
              ],

              // Title & Amount (Hide Amount if Variable)
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [CapitalizeFirstLetterTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!_isVariable) ...[
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Frequency & Due Date (Available for both types now)
              if (!_isVariable) ...[
                _buildFrequencyToggle(context),
                if (!_isDaily) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _dueDay,
                    decoration: InputDecoration(
                      labelText: 'Due Day (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    items: List.generate(31, (index) => index + 1)
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text('Day $day'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _dueDay = value),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _handleSave,
                  child: Text(
                    widget.editingItem != null
                        ? 'Update Entry'
                        : (_isVariable
                              ? 'Save Variable Entry'
                              : 'Save Quick Entry'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowTypeToggle(List<Category> categories) {
    if (_selectedCategoryId == 'other_virtual') return true;
    if (_selectedCategoryId == null) return false;
    final cat = categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    if (cat != null && cat.name.toLowerCase().contains('other')) return true;
    return false;
  }

  Widget _buildModeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleBtn(
              context,
              'Quick Entry',
              !_isVariable,
              () => setState(() => _isVariable = false),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              context,
              'Variable', // Rename One Time -> Variable
              _isVariable,
              () => setState(() => _isVariable = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(
    BuildContext context,
    String text,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconSelector(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: iconOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final iconName = iconOptions[index];
          final isSelected = _selectedIcon == iconName;
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = iconName),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.1),
              ),
              child: Icon(
                _getIconData(iconName),
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeBtn(
              context,
              'Expense',
              Colors.red,
              _isExpense,
              () => setState(() => _isExpense = true),
            ),
          ),
          Expanded(
            child: _buildTypeBtn(
              context,
              'Income',
              Colors.green,
              !_isExpense,
              () => setState(() => _isExpense = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBtn(
    BuildContext context,
    String text,
    Color color,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? color : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleBtn(
              context,
              'Daily',
              _isDaily,
              () => setState(() => _isDaily = true),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              context,
              'Monthly',
              !_isDaily,
              () => setState(() => _isDaily = false),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Replicated logic
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'commute':
        return Icons.commute;
      case 'home':
        return Icons.home;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'work':
        return Icons.work;
      case 'savings':
        return Icons.savings;
      case 'attach_money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

  Future<void> _handleSave() async {
    final provider = context.read<TransactionProvider>();

    // Resolve Category ID
    var finalCategoryId = _selectedCategoryId;
    if (finalCategoryId == null) {
      final categories = provider.categories;
      if (categories.isNotEmpty) {
        final others = categories
            .where((c) => c.name.toLowerCase().contains('other'))
            .firstOrNull;
        finalCategoryId = others?.id ?? categories.first.id;
      }
    }

    // Validation
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (!_isVariable && _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    if (finalCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    // Consolidate Save Logic
    final itemData = {
      'title': _titleController.text,
      'amount': _isVariable
          ? 0.0
          : (double.tryParse(_amountController.text) ?? 0.0),
      'frequency': _isVariable ? 'variable' : (_isDaily ? 'daily' : 'monthly'),
      'categoryId': finalCategoryId == 'other_virtual' ? null : finalCategoryId,
      'isExpense': _isExpense,
      'icon': _selectedIcon,
      'dueDay': _isDaily ? null : _dueDay,
      'isVariable': _isVariable,
      // userId handled by backend service
    };

    if (widget.editingItem != null) {
      // Update existing item
      final error = await provider.updateItem(widget.editingItem!.id, itemData);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Do not close dialog on error
      }
      await _handleNotification(widget.editingItem!.id, isUpdate: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${_titleController.text}')),
        );
      }
    } else {
      final newItem = await provider.addItem(itemData);
      if (newItem != null) {
        await _handleNotification(newItem.id, isUpdate: false);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleNotification(
    String itemId, {
    required bool isUpdate,
  }) async {
    if (_dueDay == null || _isDaily) {
      if (isUpdate)
        await NotificationService().cancelNotification(itemId.hashCode);
      return;
    }

    await NotificationService().scheduleMonthlyNotification(
      id: itemId.hashCode,
      title: 'Due: ${_titleController.text}',
      body: 'A friendly reminder to pay this bill.',
      dayOfMonth: _dueDay!,
    );
  }
}
