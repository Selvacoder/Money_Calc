import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../models/item.dart';

class CategoryCard extends StatefulWidget {
  final Category category;
  final int usageCount;
  final List<Item> items;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Item) onItemTap;
  final VoidCallback onAddItem;
  final ColorScheme colorScheme;

  const CategoryCard({
    super.key,
    required this.category,
    required this.usageCount,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onItemTap,
    required this.onAddItem,
    required this.colorScheme,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.category.type == 'expense';
    final iconColor = isExpense ? Colors.red : Colors.green;
    final bgColor = isExpense
        ? Colors.red.withOpacity(0.1)
        : Colors.green.withOpacity(0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: widget.colorScheme.outline.withOpacity(0.1)),
      ),
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            onLongPress: _showOptionsBottomSheet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: CircleAvatar(
              backgroundColor: bgColor,
              child: Icon(
                _getIconData(widget.category.icon),
                color: iconColor,
                size: 20,
              ),
            ),
            title: Text(
              widget.category.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            subtitle: widget.usageCount > 0
                ? Text(
                    '${widget.usageCount} transaction${widget.usageCount == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  )
                : null,
            trailing: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildItemsGrid(context),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.category.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Category', style: GoogleFonts.inter()),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit();
              },
            ),
            Divider(color: Colors.grey.withOpacity(0.2)),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                'Delete Category',
                style: GoogleFonts.inter(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: widget.items.length + 1, // Items + Add Button
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          return _buildAddButton(context);
        }
        return _buildItemTile(context, widget.items[index]);
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAddItem,
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.colorScheme.primary.withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2, // Made border thicker for visibility
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: widget.colorScheme.primary, size: 32),
            const SizedBox(height: 4),
            Text(
              'Add Item',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: widget.colorScheme.primary,
                fontWeight: FontWeight.w600, // Made bolder
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, Item item) {
    return GestureDetector(
      onTap: () => widget.onItemTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconData(item.icon ?? 'star'),
              color: item.isExpense ? Colors.red : Colors.green,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${item.amount}', // formatCurrency(item.amount, context) would be better if available
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
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
}
