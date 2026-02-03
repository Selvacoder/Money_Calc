import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dutch_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/appwrite_service.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberPhoneController = TextEditingController();

  String _selectedType = 'trip';
  final List<String> _types = ['trip', 'home', 'couple', 'other'];

  // List of members to add: {id, name, phone}
  final List<Map<String, String>> _membersToAdd = [];
  bool _isVerifyingMember = false;
  String? _memberError;
  String _selectedCountryCode = '+91';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verifyAndAddMember() async {
    final rawPhone = _memberPhoneController.text.trim();
    if (rawPhone.isEmpty) return;

    setState(() {
      _isVerifyingMember = true;
      _memberError = null;
    });

    try {
      // Combine Country Code + Phone
      // Remove leading 0 if present to be safe, though usually not needed if strictly E.164
      final phone = '$_selectedCountryCode$rawPhone';

      // 1. Check if self
      final currentUser = context.read<UserProvider>().user;
      if (currentUser?.phone == phone) {
        setState(() => _memberError = "You are already in the group!");
        return;
      }

      // 2. Check if already added
      if (_membersToAdd.any((m) => m['phone'] == phone)) {
        setState(() => _memberError = "Member already added.");
        return;
      }

      // 3. Lookup User
      final user = await AppwriteService().getUserByPhone(phone);
      if (user != null) {
        setState(() {
          _membersToAdd.add({
            'id': user['userId'],
            'name': user['name'] ?? 'Unknown',
            'phone': phone,
          });
          _memberPhoneController.clear();
        });
      } else {
        setState(() => _memberError = "User not found ($phone)");
      }
    } catch (e) {
      setState(() => _memberError = "Error finding user: $e");
    } finally {
      setState(() => _isVerifyingMember = false);
    }
  }

  void _removeMember(int index) {
    setState(() {
      _membersToAdd.removeAt(index);
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final dutchProvider = context.read<DutchProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final currentUser = userProvider.user;
    print('DEBUG: Current User: $currentUser');

    if (currentUser == null) {
      print('DEBUG: User is null, cannot create group');
      return;
    }

    // Compile Member IDs (CurrentUser + Added Members)
    final memberIds = [currentUser.userId];
    for (var m in _membersToAdd) {
      memberIds.add(m['id']!);
    }

    try {
      // Use the BuildContext safely
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final success = await dutchProvider.createGroup(
        name: _nameController.text.trim(),
        type: _selectedType,
        members: memberIds,
        createdBy: currentUser.userId,
        currency: currencyProvider.currencySymbol,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context); // Close Dialog
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                dutchProvider.error ?? 'Unknown error creating group',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<DutchProvider>().isLoading;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Group',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Group Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Goa Trip 2024',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Group Type
                Text(
                  'Type',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _types.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type[0].toUpperCase() + type.substring(1)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedType = type);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Members Section
                Text(
                  'Members',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Added Members List
                if (_membersToAdd.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _membersToAdd.asMap().entries.map((entry) {
                        final index = entry.key;
                        final m = entry.value;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade100,
                            child: Text(m['name']![0].toUpperCase()),
                          ),
                          title: Text(m['name']!),
                          subtitle: Text(m['phone']!),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeMember(index),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Add Member Input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        onChanged: (code) {
                          if (code.dialCode != null) {
                            _selectedCountryCode = code.dialCode!;
                          }
                        },
                        // Initial selection and favorite list
                        initialSelection: 'IN',
                        favorite: const ['+91', 'US'],
                        // optional parameters
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _memberPhoneController,
                        decoration: InputDecoration(
                          hintText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: IconButton.filled(
                        onPressed: _isVerifyingMember
                            ? null
                            : _verifyAndAddMember,
                        icon: _isVerifyingMember
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
                if (_memberError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _memberError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 32),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _createGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Group'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
