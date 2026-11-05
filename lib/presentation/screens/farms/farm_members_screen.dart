import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/farm.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/detail_ui.dart';
import '../../common/widgets/finance_ui.dart';

/// Everyone who works on a farm: roles, what they can do, add / edit /
/// pause / remove. Changes are saved on the farm record and logged in its
/// activity feed.
class FarmMembersScreen extends ConsumerStatefulWidget {
  const FarmMembersScreen({super.key, required this.farmId});

  final String farmId;

  @override
  ConsumerState<FarmMembersScreen> createState() => _FarmMembersScreenState();
}

class _FarmMembersScreenState extends ConsumerState<FarmMembersScreen> {
  FarmWorkspaceRole? _roleFilter;

  Farm? _farm() {
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    for (final Farm f in farms) {
      if (f.id == widget.farmId) return f;
    }
    return null;
  }

  Color _roleColor(FarmWorkspaceRole role) {
    switch (role) {
      case FarmWorkspaceRole.owner:
      case FarmWorkspaceRole.coOwner:
        return const Color(0xFFD99A1E);
      case FarmWorkspaceRole.manager:
        return const Color(0xFF2E9E5B);
      case FarmWorkspaceRole.supervisor:
        return const Color(0xFF0EA5A4);
      case FarmWorkspaceRole.worker:
        return const Color(0xFF8B5CF6);
      case FarmWorkspaceRole.partner:
        return const Color(0xFFE0724A);
      case FarmWorkspaceRole.viewer:
        return const Color(0xFF8A93A2);
    }
  }

  String _roleName(FarmWorkspaceRole role) => FarmWorkspaceMember(
        id: '',
        name: '',
        email: '',
        role: role,
        allowedFarmIds: const <String>[],
        financeAccess: FarmFinanceAccess.none,
        createdAt: DateTime(2000),
        updatedAt: DateTime(2000),
      ).roleLabel;

  Future<void> _save(
    Farm farm,
    List<FarmWorkspaceMember> members,
    String action,
    String detail,
  ) async {
    final DateTime now = DateTime.now();
    final Farm updated = farm.copyWith(
      workspaceMembers: members,
      activityLog: <FarmActivityRecord>[
        FarmActivityRecord(
          id: const Uuid().v4(),
          actorName: 'System',
          actorRole: FarmWorkspaceRole.owner,
          action: action,
          detail: detail,
          audience: farm.ownerCount > 1
              ? FarmActivityAudience.owners
              : FarmActivityAudience.workspace,
          createdAt: now,
        ),
        ...farm.activityLog,
      ],
      updatedAt: now,
      isSynced: false,
    );
    await ref.read(farmsProvider.notifier).updateFarm(updated);
  }

  Future<void> _addOrEdit(Farm farm, {FarmWorkspaceMember? existing}) async {
    final FarmWorkspaceMember? result =
        await showModalBottomSheet<FarmWorkspaceMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberSheet(farm: farm, existing: existing),
    );
    if (result == null || !mounted) return;
    HapticFeedback.lightImpact();
    final List<FarmWorkspaceMember> members;
    if (existing == null) {
      // If the email already belongs to an app user, attach their real id.
      FarmWorkspaceMember member = result;
      if (result.email.isNotEmpty) {
        try {
          final dynamic profile = await ref
              .read(firebaseServiceProvider)
              .findUserProfileByEmail(result.email);
          if (profile != null) {
            member = result.copyWith(
                id: profile.uid as String, isActive: true);
          }
        } catch (_) {}
      }
      members = <FarmWorkspaceMember>[member, ...farm.workspaceMembers];
      await _save(farm, members, 'Added member',
          '${member.name} joined as ${member.roleLabel}.');
    } else {
      members = farm.workspaceMembers
          .map((FarmWorkspaceMember m) => m.id == existing.id ? result : m)
          .toList();
      await _save(farm, members, 'Updated member',
          '${result.name}\'s role and access were updated.');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(existing == null ? 'Member added.' : 'Member updated.')));
  }

  Future<void> _toggleActive(Farm farm, FarmWorkspaceMember m) async {
    HapticFeedback.selectionClick();
    final FarmWorkspaceMember next =
        m.copyWith(isActive: !m.isActive, updatedAt: DateTime.now());
    await _save(
      farm,
      farm.workspaceMembers
          .map((FarmWorkspaceMember x) => x.id == m.id ? next : x)
          .toList(),
      next.isActive ? 'Reactivated member' : 'Paused member',
      '${m.name} was ${next.isActive ? 'reactivated' : 'paused'}.',
    );
  }

  Future<void> _remove(Farm farm, FarmWorkspaceMember m) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text(
            'They lose access to this farm straight away. Their past activity stays in the log.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.mediumImpact();
    await _save(
      farm,
      farm.workspaceMembers
          .where((FarmWorkspaceMember x) => x.id != m.id)
          .toList(growable: false),
      'Removed member',
      '${m.name} was removed from the farm workspace.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Farm? farm = _farm();
    if (farm == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Members')),
        body: const Center(child: Text('Farm not found.')),
      );
    }
    final List<FarmWorkspaceMember> all = farm.workspaceMembers;
    final List<FarmWorkspaceMember> shown = all
        .where((FarmWorkspaceMember m) =>
            _roleFilter == null || m.role == _roleFilter)
        .toList();
    final int active = all.where((FarmWorkspaceMember m) => m.isActive).length;
    final int pending = all
        .where((FarmWorkspaceMember m) => !m.isActive && m.email.isNotEmpty)
        .length;
    final Set<FarmWorkspaceRole> rolesPresent =
        all.map((FarmWorkspaceMember m) => m.role).toSet();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/farms'),
        ),
        title: Text('${farm.name} team'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(farm),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add member'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: <Widget>[
          MetricStrip(
            stats: <MetricStat>[
              MetricStat(
                icon: Icons.groups_rounded,
                label: 'Members',
                value: '${all.length}',
              ),
              MetricStat(
                icon: Icons.check_circle_rounded,
                label: 'Active',
                value: '$active',
                color: const Color(0xFF2E9E5B),
              ),
              MetricStat(
                icon: Icons.mail_outline_rounded,
                label: 'Invited',
                value: '$pending',
                color: const Color(0xFFD99A1E),
              ),
              MetricStat(
                icon: Icons.checklist_rounded,
                label: 'Open tasks',
                value: '${farm.openWorkspaceTaskCount}',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rolesPresent.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Everyone'),
                      selected: _roleFilter == null,
                      onSelected: (_) => setState(() => _roleFilter = null),
                    ),
                  ),
                  for (final FarmWorkspaceRole r in rolesPresent)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_roleName(r)),
                        selected: _roleFilter == r,
                        onSelected: (_) => setState(
                            () => _roleFilter = _roleFilter == r ? null : r),
                      ),
                    ),
                ],
              ),
            ),
          if (rolesPresent.length > 1) const SizedBox(height: 12),
          if (all.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: <Widget>[
                  const Text('👩🏾‍🌾', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text('Build your farm team',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    'Add managers, workers or partners, choose what each can see and do, and assign them tasks.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < shown.length; i++)
              FadeInUp(
                index: i > 5 ? 5 : i,
                child: _MemberCard(
                  member: shown[i],
                  color: _roleColor(shown[i].role),
                  onEdit: () => _addOrEdit(farm, existing: shown[i]),
                  onToggle: () => _toggleActive(farm, shown[i]),
                  onRemove: () => _remove(farm, shown[i]),
                ),
              ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.color,
    required this.onEdit,
    required this.onToggle,
    required this.onRemove,
  });

  final FarmWorkspaceMember member;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initials = member.name.trim().isEmpty
        ? '?'
        : member.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((String p) => p[0].toUpperCase())
            .join();
    final List<String> perms = <String>[
      if (member.canManageTasks) 'Tasks',
      if (member.canManageSchedule) 'Schedule',
      if (member.canPostUpdates) 'Updates',
      if (member.canViewActivityLog) 'Activity log',
    ];
    final String status = member.isActive
        ? 'Active'
        : member.email.isNotEmpty
            ? 'Invited'
            : 'Paused';

    return Opacity(
      opacity: member.isActive ? 1 : 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[color, color.withOpacity(0.6)],
                    ),
                  ),
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      Text(
                        member.email.isNotEmpty
                            ? member.email
                            : (member.phone.isNotEmpty
                                ? member.phone
                                : 'No contact saved'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (String v) {
                    if (v == 'edit') onEdit();
                    if (v == 'toggle') onToggle();
                    if (v == 'remove') onRemove();
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                        value: 'edit', child: Text('Edit role & access')),
                    PopupMenuItem<String>(
                        value: 'toggle',
                        child: Text(member.isActive ? 'Pause' : 'Reactivate')),
                    const PopupMenuItem<String>(
                        value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _chip(member.roleLabel, color),
                _chip(member.financeAccessLabel,
                    theme.colorScheme.onSurfaceVariant),
                _chip(status,
                    member.isActive ? const Color(0xFF2E9E5B) : const Color(0xFFD99A1E)),
                if (member.hasScopedRecordAccess)
                  _chip(
                      '${member.allowedCropIds.length} crops · ${member.allowedLivestockIds.length} animal groups',
                      const Color(0xFF0EA5A4)),
              ],
            ),
            if (perms.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('Can: ${perms.join(' · ')}',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withOpacity(0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(
                color: c, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.farm, this.existing});

  final Farm farm;
  final FarmWorkspaceMember? existing;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late FarmWorkspaceRole _role =
      widget.existing?.role ?? FarmWorkspaceRole.worker;
  late FarmFinanceAccess _finance =
      widget.existing?.financeAccess ?? FarmFinanceAccess.none;
  late bool _tasks = widget.existing?.canManageTasks ?? false;
  late bool _schedule = widget.existing?.canManageSchedule ?? false;
  late bool _updates = widget.existing?.canPostUpdates ?? false;
  late bool _log = widget.existing?.canViewActivityLog ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _label(FarmFinanceAccess a) {
    switch (a) {
      case FarmFinanceAccess.none:
        return 'No finance access';
      case FarmFinanceAccess.viewOnly:
        return 'View finance';
      case FarmFinanceAccess.recordOnly:
        return 'Record finance';
      case FarmFinanceAccess.manage:
        return 'Manage finance';
    }
  }

  String _roleLabel(FarmWorkspaceRole r) => FarmWorkspaceMember(
        id: '',
        name: '',
        email: '',
        role: r,
        allowedFarmIds: const <String>[],
        financeAccess: FarmFinanceAccess.none,
        createdAt: DateTime(2000),
        updatedAt: DateTime(2000),
      ).roleLabel;

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter the member\'s name.');
      return;
    }
    final DateTime now = DateTime.now();
    final FarmWorkspaceMember? e = widget.existing;
    final FarmWorkspaceMember member = e != null
        ? e.copyWith(
            name: name,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            financeAccess: _finance,
            canManageTasks: _tasks,
            canManageSchedule: _schedule,
            canPostUpdates: _updates,
            canViewActivityLog: _log,
            updatedAt: now,
          )
        : FarmWorkspaceMember(
            id: const Uuid().v4(),
            name: name,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            allowedFarmIds: <String>[widget.farm.id],
            financeAccess: _finance,
            canManageTasks: _tasks,
            canManageSchedule: _schedule,
            canPostUpdates: _updates,
            canViewActivityLog: _log,
            createdAt: now,
            updatedAt: now,
            isActive: _email.text.trim().isEmpty,
          );
    Navigator.of(context).pop(member);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.existing == null ? 'Add member' : 'Edit member',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full name',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (to invite them to the app)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Role', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final FarmWorkspaceRole r in FarmWorkspaceRole.values)
                      ChoiceChip(
                        label: Text(_roleLabel(r)),
                        selected: _role == r,
                        onSelected: (_) => setState(() => _role = r),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<FarmFinanceAccess>(
                  value: _finance,
                  decoration: const InputDecoration(
                      labelText: 'Finance access',
                      border: OutlineInputBorder()),
                  items: <DropdownMenuItem<FarmFinanceAccess>>[
                    for (final FarmFinanceAccess a in FarmFinanceAccess.values)
                      DropdownMenuItem<FarmFinanceAccess>(
                          value: a, child: Text(_label(a))),
                  ],
                  onChanged: (FarmFinanceAccess? v) =>
                      setState(() => _finance = v ?? _finance),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can manage tasks'),
                  value: _tasks,
                  onChanged: (bool v) => setState(() => _tasks = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can manage schedule'),
                  value: _schedule,
                  onChanged: (bool v) => setState(() => _schedule = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can post updates'),
                  value: _updates,
                  onChanged: (bool v) => setState(() => _updates = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Can view activity log'),
                  value: _log,
                  onChanged: (bool v) => setState(() => _log = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(widget.existing == null
                          ? 'Add to team'
                          : 'Save changes'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
