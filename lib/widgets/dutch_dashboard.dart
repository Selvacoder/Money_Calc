import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/dutch_provider.dart';
import '../screens/dutch/group_details_screen.dart';
import 'dutch/create_group_dialog.dart';

class DutchDashboard extends StatefulWidget {
  const DutchDashboard({super.key});

  @override
  State<DutchDashboard> createState() => _DutchDashboardState();
}

class _DutchDashboardState extends State<DutchDashboard> {
  int _currentPage = 0; // 0=Overall, 1=Yearly, 2=Monthly, 3=Weekly, 4=Daily

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = context.read<DutchProvider>();
      print('DEBUG Dashboard: Fetching groups and global data...');
      provider.fetchGroups();
      provider.fetchGlobalData().then((_) {
        print('DEBUG Dashboard: Global data fetched');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DutchProvider>();
    final groups = provider.groups;
    final isLoading = provider.isLoading;

    return RefreshIndicator(
      onRefresh: () async {
        final provider = context.read<DutchProvider>();
        await provider.fetchGroups();
        await provider.fetchGlobalData();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200 &&
              !isLoading &&
              provider.hasMoreGroups) {
            provider.loadMoreGroups();
          }
          return true;
        },
        child: Stack(
          fit: StackFit.expand, // Ensure Stack fills the available space
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80), // Add padding for FAB
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header / Net Balance Placeholder
                    // Balance Card with time period filtering
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPage = (_currentPage + 1) % 5;
                        });
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.9,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: KeyedSubtree(
                          key: ValueKey<int>(_currentPage),
                          child: _buildCurrentShareCard(provider, context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Groups',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const CreateGroupDialog(),
                            );
                          },
                          icon: Icon(
                            Icons.add_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (isLoading && groups.isEmpty)
                      const Center(child: CircularProgressIndicator()),

                    if (provider.error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.error!,
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () {
                                context.read<DutchProvider>().fetchGroups();
                              },
                            ),
                          ],
                        ),
                      ),

                    if (!isLoading && groups.isEmpty && provider.error == null)
                      SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No groups yet',
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateGroupDialog(),
                                  );
                                },
                                child: const Text('Create a Group'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (groups.isNotEmpty)
                      Column(
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              return _buildGroupCard(group);
                            },
                          ),
                          if (provider.hasMoreGroups)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showInviteCodeDialog(context),
                label: Text(
                  'Invite Code',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailsScreen(group: group)),
        );
      },
      onLongPress: () => _showGroupOptions(context, group),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(group['icon']),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const Spacer(),
            Text(
              group['name'] ?? 'Unnamed',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Settled up', // TODO: Group specific balance
              style: GoogleFonts.inter(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.greenAccent
                    : Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentShareCard(DutchProvider provider, BuildContext context) {
    String title;
    double share;
    DateTime? startDate;
    final now = DateTime.now();

    print(
      'DEBUG _buildCurrentShareCard: currentPage=$_currentPage, currentUserId=${provider.currentUserId}',
    );

    switch (_currentPage) {
      case 0: // Overall
        title = 'Overall Share';
        share = provider.getGlobalUserShare();
        print('DEBUG Overall Share called, result=$share');
        break;
      case 1: // Yearly
        title = 'Yearly Share';
        startDate = DateTime(now.year, 1, 1);
        share = provider.getGlobalUserShare(startDate: startDate);
        break;
      case 2: // Monthly
        title = 'Monthly Share';
        startDate = DateTime(now.year, now.month, 1);
        share = provider.getGlobalUserShare(startDate: startDate);
        break;
      case 3: // Weekly
        title = 'Weekly Share';
        startDate = now.subtract(const Duration(days: 7));
        share = provider.getGlobalUserShare(startDate: startDate);
        break;
      case 4: // Daily
      default:
        title = 'Daily Share';
        startDate = DateTime(now.year, now.month, now.day);
        share = provider.getGlobalUserShare(startDate: startDate);
        break;
    }

    return Container(
      key: ValueKey<int>(_currentPage),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${share.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(BuildContext context) {
    final inviteController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Join via Invite Code',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the invite code shared by the group admin to join.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: inviteController,
                    decoration: InputDecoration(
                      labelText: 'Invite Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isJoining ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isJoining
                      ? null
                      : () async {
                          if (inviteController.text.trim().isNotEmpty) {
                            setState(() => isJoining = true);

                            // Use the outer context or ensure provider is accessible
                            // Often accessing provider from dialog context works if provider is high enough
                            final provider = context.read<DutchProvider>();
                            final success = await provider.joinGroup(
                              inviteController.text.trim(),
                            );

                            if (context.mounted) {
                              setState(() => isJoining = false);
                              if (success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Successfully joined group!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                final error =
                                    provider.error ?? 'Failed to join group';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGroupOptions(BuildContext context, Map<String, dynamic> group) {
    final provider = context.read<DutchProvider>();
    final isCreator = group['createdBy'] == provider.currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Group'),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _showEditGroupDialog(context, group);
                },
              ),
              if (isCreator)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Group',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close sheet
                    _deleteGroup(context, group['id']);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditGroupDialog(BuildContext context, Map<String, dynamic> group) {
    final nameController = TextEditingController(text: group['name']);
    String rawType = group['type']?.toString() ?? 'Trip';
    // Capitalize first letter to match dropdown items if needed
    if (rawType.isNotEmpty && rawType.length > 1) {
      rawType = rawType[0].toUpperCase() + rawType.substring(1).toLowerCase();
    }
    const validTypes = ['Trip', 'Home', 'Couple', 'Other'];
    String selectedType = validTypes.contains(rawType) ? rawType : 'Trip';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Group Name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: ['Trip', 'Home', 'Couple', 'Other']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedType = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.isNotEmpty) {
                            setState(() => isSaving = true);
                            final success = await context
                                .read<DutchProvider>()
                                .updateGroup(
                                  group['id'],
                                  nameController.text.trim(),
                                  selectedType,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Group updated'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update group'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteGroup(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group?'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close confirmation
              final success = await context.read<DutchProvider>().deleteGroup(
                groupId,
              );
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete group'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? name) {
    if (name == null) return Icons.group;
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
