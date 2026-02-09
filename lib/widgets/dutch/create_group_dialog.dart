import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dutch_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/appwrite_service.dart';
import '../../utils/formatters.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String _selectedType = 'trip';
  final List<String> _types = ['trip', 'home', 'couple', 'other'];

  String _selectedIcon = 'flight_takeoff';
  final List<String> _icons = [
    'flight_takeoff',
    'home',
    'favorite',
    'celebration',
    'restaurant',
    'shopping_bag',
    'bolt',
    'movie',
    'sports_esports',
    'pets',
  ];

  // List of members to add: {id, name, phone}
  final List<Map<String, String>> _membersToAdd = [];
  String? _memberError;
  bool _showInvite = false; // Added state
  String _invitePhone = '';
  String _selectedCountryCode = '+91';
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _contacts = [];
  bool _contactsLoaded = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (_contactsLoaded) return;
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      try {
        final contacts = await FastContacts.getAllContacts(
          fields: [ContactField.displayName, ContactField.phoneNumbers],
        );
        if (mounted) {
          setState(() {
            _contacts = contacts;
            _contactsLoaded = true;
          });
        }
      } catch (e) {
        debugPrint('Error loading contacts: $e');
      }
    }
  }

  bool get _hasNonAppMembers =>
      _membersToAdd.any((m) => m['id'] == null || m['id']!.isEmpty);

  void _removeMember(int index) {
    setState(() {
      final removed = _membersToAdd.removeAt(index);
      if (_invitePhone == removed['phone']) {
        _showInvite = false;
        _invitePhone = '';
      }
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

      final rawName = _nameController.text.trim();
      final name = rawName.isNotEmpty
          ? rawName[0].toUpperCase() + rawName.substring(1)
          : rawName;

      final success = await dutchProvider.createGroup(
        name: name,
        type: _selectedType,
        members: memberIds,
        createdBy: currentUser.userId,
        currency: currencyProvider.currencySymbol,
        icon: _selectedIcon,
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
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [CapitalizeFirstLetterTextFormatter()],
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

                // Icon Selector
                Text(
                  'Icon',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final iconName = _icons[index];
                      final isSelected = _selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
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

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) async {
                    setState(() {
                      if (value.isEmpty) {
                        _searchResults = [];
                      } else {
                        _searchResults = _contacts
                            .where((contact) {
                              final name = contact.displayName;
                              final nameMatch = name.toLowerCase().contains(
                                value.toLowerCase(),
                              );
                              final phones = contact.phones;
                              final phoneMatch = phones.any(
                                (p) => p.number.contains(value),
                              );
                              return nameMatch || phoneMatch;
                            })
                            .take(5)
                            .toList();
                      }
                    });

                    if (value.length >= 3) {
                      try {
                        final remoteUsers = await AppwriteService()
                            .searchContacts(value);
                        if (_searchController.text == value) {
                          setState(() {
                            for (var user in remoteUsers) {
                              final phone = user['phone'];
                              bool exists = _searchResults.any((r) {
                                if (r is Contact) {
                                  return r.phones.any(
                                    (p) => p.number.contains(phone),
                                  );
                                }
                                return r['phone'] == phone;
                              });
                              if (!exists) {
                                _searchResults.add({...user, 'isRemote': true});
                              }
                            }
                          });
                        }
                      } catch (e) {
                        debugPrint('Error in remote search: $e');
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or number...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),

                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        String name = '';
                        String phone = '';
                        bool isRemote = false;

                        if (item is Contact) {
                          name = item.displayName;
                          phone = item.phones.isNotEmpty
                              ? item.phones.first.number
                              : '';
                        } else {
                          name = item['name'] ?? '';
                          phone = item['phone'] ?? '';
                          isRemote = item['isRemote'] ?? false;
                        }

                        return ListTile(
                          visualDensity: VisualDensity.compact,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isRemote)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'On Tap It',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: phone.isNotEmpty
                              ? Text(
                                  phone,
                                  style: GoogleFonts.inter(fontSize: 11),
                                )
                              : null,
                          onTap: () async {
                            final cleanPhone = phone.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            final formattedPhone = cleanPhone.length >= 10
                                ? cleanPhone.substring(cleanPhone.length - 10)
                                : cleanPhone;

                            // Add to members list
                            setState(() {
                              _membersToAdd.add({
                                'id': item is Contact
                                    ? ''
                                    : (item['userId'] ?? ''),
                                'name': name,
                                'phone': '$_selectedCountryCode$formattedPhone',
                              });
                              _searchResults = [];
                              _searchController.clear();
                              _memberError = null;
                              _showInvite = false; // Reset before check
                            });

                            // If it's a local contact, try to check if they are registered
                            if (item is Contact) {
                              try {
                                final fullPhone =
                                    '$_selectedCountryCode$formattedPhone';
                                final user = await AppwriteService()
                                    .getUserByPhone(fullPhone);
                                if (user != null) {
                                  setState(() {
                                    final last = _membersToAdd.last;
                                    last['id'] = user['userId'];
                                    last['name'] = user['name'] ?? last['name'];
                                    _showInvite = false;
                                  });
                                } else {
                                  setState(() {
                                    _showInvite = true;
                                    _invitePhone = fullPhone;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error checking registration: $e');
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Added Members List
                if (_membersToAdd.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: _membersToAdd.asMap().entries.map((entry) {
                        final index = entry.key;
                        final m = entry.value;
                        final isAppUser =
                            m['id'] != null && m['id']!.isNotEmpty;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: isAppUser
                                ? Colors.deepPurple.shade100
                                : Colors.grey.shade300,
                            child: Text(
                              m['name']![0].toUpperCase(),
                              style: TextStyle(
                                color: isAppUser
                                    ? Colors.deepPurple
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          title: Text(
                            m['name']!,
                            style: TextStyle(
                              color: isAppUser
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.grey,
                            ),
                          ),
                          subtitle: Text(m['phone']!),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeMember(index),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_hasNonAppMembers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Only app users can be added to groups. Please remove others.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                if (_memberError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _memberError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                if (_showInvite)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          if (_invitePhone.isNotEmpty) {
                            final url = Uri.parse(
                              'https://wa.me/$_invitePhone?text=Hey! Join me on Tap It to track our shared expenses easily. Download it here: [Link]',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Invite via WhatsApp'),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Actions
                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isLoading || _hasNonAppMembers)
                        ? null
                        : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'flight_takeoff':
        return Icons.flight_takeoff;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'celebration':
        return Icons.celebration;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'bolt':
        return Icons.bolt;
      case 'movie':
        return Icons.movie;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.group;
    }
  }
}
