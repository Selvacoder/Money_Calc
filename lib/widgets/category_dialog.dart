import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../utils/formatters.dart';

class CategoryDialog extends StatefulWidget {
  final Category? category; // If null, it's Add mode
  final String? initialType; // For Add mode, pre-select type

  const CategoryDialog({super.key, this.category, this.initialType});

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late TextEditingController _nameController;
  late String _selectedType;

  late String _selectedIcon;
  bool _hasTransactions = false;
  String? _suggestionMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedType = widget.category?.type ?? widget.initialType ?? 'expense';
    _selectedIcon =
        widget.category?.icon ??
        (_selectedType == 'expense' ? 'shopping_cart' : 'work');

    if (widget.category != null) {
      // Check if category has transactions to lock type
      _hasTransactions = context
          .read<TransactionProvider>()
          .hasTransactionsForCategory(widget.category!.id);
    }

    // Listen to name changes
    _nameController.addListener(_checkSuggestions);
  }

  void _checkSuggestions() {
    final name = _nameController.text.toLowerCase();
    String? message;

    // Helper check
    bool matches(String text, List<String> keywords) {
      return keywords.any((k) => text.contains(k));
    }

    final ledgerKeywords = [
      'loan',
      'lend',
      'borrow',
      'repay',
      'debt',
      'owe',
      'ledger',
    ];
    final investmentKeywords = [
      'stock',
      'mutual fund',
      'sip',
      'equity',
      'crypto',
      'bitcoin',
      'invest',
    ];
    final dutchKeywords = ['split', 'share', 'dutch', 'group', 'trip'];

    if (matches(name, ledgerKeywords)) {
      message = 'Tracking loans? The Ledger feature is perfect for this.';
    } else if (matches(name, investmentKeywords)) {
      message = 'For investments, check out the dedicated Investment section.';
    } else if (matches(name, dutchKeywords)) {
      message = 'Group expenses are best managed in the "Go Dutch" section.';
    }

    if (message != _suggestionMessage) {
      setState(() {
        _suggestionMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkSuggestions);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.category == null ? 'Add Category' : 'Edit Category',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Income/Expense Toggle at top
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeToggleButton(
                      context,
                      'Expense',
                      'expense',
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildTypeToggleButton(
                      context,
                      'Income',
                      'income',
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (_hasTransactions)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Type cannot be changed because this category is in use.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Suggestion Banner
            if (_suggestionMessage != null) ...[
              _buildSuggestionBanner(context),
              const SizedBox(height: 16),
            ],

            // Category Name
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [CapitalizeFirstLetterTextFormatter()],
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Icon',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height:
                  120, // Fixed height to accommodate 2 rows of icons (50+8+50 + padding)
              width: double.maxFinite, // Force full width
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _getIconList(_selectedType).map((iconName) {
                    final isSelected = _selectedIcon == iconName;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconName;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconData(iconName),
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.grey,
                          size: 28,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter()),
        ),
        ElevatedButton(
          onPressed: _saveCategory,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(
            widget.category == null ? 'Add' : 'Save',
            style: GoogleFonts.inter(),
          ),
        ),
      ],
    );
  }

  void _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<TransactionProvider>();

    // Duplicate Check
    // If editing, check if name changed. If same, no check needed (unless type changed, but type is locked if used).
    // Actually, even if same name, we need to ensure we don't collide with ANOTHER category.
    bool checkDuplicate = true;
    if (widget.category != null &&
        widget.category!.name.toLowerCase() == name.toLowerCase() &&
        widget.category!.type == _selectedType) {
      checkDuplicate = false;
    }

    if (checkDuplicate) {
      if (provider.isCategoryNameDuplicate(name, _selectedType)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Category already exists'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    if (widget.category == null) {
      // Add
      final newCategory = await provider.addCategory(
        name,
        _selectedType,
        _selectedIcon,
      ); // returns Category?

      if (newCategory == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to add category. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return; // Don't pop if failed
      }
      if (context.mounted) {
        Navigator.pop(context, newCategory.id); // Return ID
      }
      return;
    } else {
      // Update
      // Temporary: Call updateCategoryName (which is what we have)
      provider.updateCategory(
        widget.category!.id,
        name,
        icon: _selectedIcon,
        type: _selectedType,
      );
      if (context.mounted) {
        Navigator.pop(context); // No return value for edit needed usually
      }
    }
  }

  Widget _buildTypeToggleButton(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final isSelected = _selectedType == value;
    final isDisabled = _hasTransactions;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedType = value;
                if (_selectedType == 'income' &&
                    _selectedIcon == 'shopping_cart') {
                  _selectedIcon = 'work';
                } else if (_selectedType == 'expense' &&
                    _selectedIcon == 'work') {
                  _selectedIcon = 'shopping_cart';
                }
              });
            },
      child: Container(
        height: 48, // Enforce fixed height
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
            width: 1, // Always 1px width
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hidden bold text to reserve width
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.transparent,
                  fontSize: 14, // Explicit font size
                ),
              ),
              // Visible text
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDisabled
                      ? Colors.grey
                      : (isSelected ? color : Colors.grey[600]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14, // Explicit font size matches hidden text
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getIconList(String type) {
    if (type == 'expense') {
      return [
        'shopping_cart',
        'restaurant',
        'commute',
        'home',
        'medical_services',
        'school',
        'fitness_center',
      ];
    } else {
      return ['work', 'savings', 'attach_money'];
    }
  }

  IconData _getIconData(String iconName) {
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

  Widget _buildSuggestionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _suggestionMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _suggestionMessage = null; // Dismiss
              });
            },
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
