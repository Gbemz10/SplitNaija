import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groupService = context.read<GroupService>();
    final groups = await groupService.listMyGroups(); // returns [] until GET /groups exists — see README
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _createGroupDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await context.read<GroupService>().createGroup(name.trim());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Groups')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroupDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('No groups yet — create one to start.'))
              : ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (context, i) {
                    final group = _groups[i];
                    return ListTile(
                      title: Text(group.name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group, authService: widget.authService),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
