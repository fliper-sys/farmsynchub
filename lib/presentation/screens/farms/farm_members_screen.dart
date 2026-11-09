import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/context_tr.dart';
import '../../../domain/models/farm.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../common/widgets/detail_ui.dart';
import '../../common/widgets/finance_ui.dart';

/// Everyone who works on a farm: roles, what they can do, add / edit /
/// pause / remove. Changes are saved on the farm record and logged in its
/// activity feed.
String _roleText(BuildContext c, FarmWorkspaceRole r) {
  switch (r) {
    case FarmWorkspaceRole.owner:
      return ctr(c, 'Owner', 'Mai gona', 'Propriétaire', 'Owner');
    case FarmWorkspaceRole.coOwner:
      return ctr(c, 'Co-owner', 'Abokin mallaka', 'Copropriétaire', 'Co-owner');
    case FarmWorkspaceRole.manager:
      return ctr(c, 'Manager', 'Manaja', 'Gérant', 'Manager');
    case FarmWorkspaceRole.supervisor:
      return ctr(c, 'Supervisor', 'Mai kulawa', 'Superviseur', 'Supervisor');
    case FarmWorkspaceRole.worker:
      return ctr(c, 'Worker', 'Ma\'aikaci', 'Ouvrier', 'Worker');
    case FarmWorkspaceRole.partner:
      return ctr(c, 'Partner', 'Abokin tarayya', 'Partenaire', 'Partner');
    case FarmWorkspaceRole.viewer:
      return ctr(c, 'Viewer', 'Mai kallo', 'Observateur', 'Viewer');
  }
}

String _financeText(BuildContext c, FarmFinanceAccess a) {
  switch (a) {
    case FarmFinanceAccess.none:
      return ctr(c, 'No finance access', 'Babu damar kudi', 'Pas d’accès aux finances', 'No access to money records');
    case FarmFinanceAccess.viewOnly:
      return ctr(c, 'View finance', 'Duba kudi', 'Voir les finances', 'See money records');
    case FarmFinanceAccess.recordOnly:
      return ctr(c, 'Record finance', 'Rubuta kudi', 'Saisir les finances', 'Record money');
    case FarmFinanceAccess.manage:
      return ctr(c, 'Manage finance', 'Sarrafa kudi', 'Gérer les finances', 'Manage money records');
  }
}

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

  String _roleName(FarmWorkspaceRole role) => _roleText(context, role);

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
        content: Text(existing == null
            ? ctr(context, 'Member added.', 'An kara memba.', 'Membre ajouté.', 'Member don add.')
            : ctr(context, 'Member updated.', 'An sabunta memba.', 'Membre mis à jour.', 'Member don update.'))));
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
        title: Text(ctr(ctx, 'Remove ${m.name}?', 'Cire ${m.name}?', 'Retirer ${m.name} ?', 'Remove ${m.name}?')),
        content: Text(ctr(ctx, 'They lose access to this farm straight away. Their past activity stays in the log.', 'Za su rasa damar shiga wannan gona nan take. Ayyukansu na baya za su ci gaba da kasancewa a cikin rajista.', 'Ils perdent immédiatement l’accès à cette ferme. Leur activité passée reste dans le journal.', 'Dem go lose access to this farm sharp sharp. Their old activity go still dey inside the log.')),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctr(ctx, 'Cancel', 'Soke', 'Annuler', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctr(ctx, 'Remove', 'Cire', 'Retirer', 'Remove'))),
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
        appBar: AppBar(title: Text(ctr(context, 'Members', 'Membobi', 'Membres', 'Members'))),
        body: Center(child: Text(ctr(context, 'Farm not found.', 'Ba a sami gona ba.', 'Ferme introuvable.', 'We no see the farm.'))),
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
        title: Text('${farm.name} ${ctr(context, 'team', 'ƙungiya', 'équipe', 'team')}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(farm),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(ctr(context, 'Add member', 'Kara memba', 'Ajouter un membre', 'Add member')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: <Widget>[
          MetricStrip(
            stats: <MetricStat>[
              MetricStat(
                icon: Icons.groups_rounded,
                label: ctr(context, 'Members', 'Membobi', 'Membres', 'Members'),
                value: '${all.length}',
              ),
              MetricStat(
                icon: Icons.check_circle_rounded,
                label: ctr(context, 'Active', 'Masu aiki', 'Actifs', 'Active'),
                value: '$active',
                color: const Color(0xFF2E9E5B),
              ),
              MetricStat(
                icon: Icons.mail_outline_rounded,
                label: ctr(context, 'Invited', 'An gayyata', 'Invités', 'Invited'),
                value: '$pending',
                color: const Color(0xFFD99A1E),
              ),
              MetricStat(
                icon: Icons.checklist_rounded,
                label: ctr(context, 'Open tasks', 'Ayyukan da ke buɗe', 'Tâches ouvertes', 'Open tasks'),
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
                      label: Text(ctr(context, 'Everyone', 'Kowa', 'Tout le monde', 'Everybody')),
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
                  Text(ctr(context, 'Build your farm team', 'Gina ƙungiyar gonarka', 'Constituez votre équipe agricole', 'Build your farm team'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    ctr(context, 'Add managers, workers or partners, choose what each can see and do, and assign them tasks.', 'Kara manajoji, ma\'aikata ko abokan tarayya, zaɓi abin da kowanne zai iya gani da yi, sannan ka ba su ayyuka.', 'Ajoutez des gérants, ouvriers ou partenaires, choisissez ce que chacun peut voir et faire, et assignez-leur des tâches.', 'Add managers, workers or partners, choose wetin each one fit see and do, and give dem tasks.'),
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
      if (member.canManageTasks) ctr(context, 'Tasks', 'Ayyuka', 'Tâches', 'Tasks'),
      if (member.canManageSchedule) ctr(context, 'Schedule', 'Jadawali', 'Calendrier', 'Schedule'),
      if (member.canPostUpdates) ctr(context, 'Updates', 'Sabuntawa', 'Mises à jour', 'Updates'),
      if (member.canViewActivityLog) ctr(context, 'Activity log', 'Rajistar ayyuka', 'Journal d’activité', 'Activity log'),
    ];
    final String status = member.isActive
        ? ctr(context, 'Active', 'Yana aiki', 'Actif', 'Active')
        : member.email.isNotEmpty
            ? ctr(context, 'Invited', 'An gayyata', 'Invité', 'Invited')
            : ctr(context, 'Paused', 'An dakatar', 'En pause', 'Paused');

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
                                : ctr(context, 'No contact saved', 'Babu bayanin tuntuɓa', 'Aucun contact enregistré', 'No contact don save')),
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
                    PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(ctr(context, 'Edit role & access', 'Gyara matsayi da dama', 'Modifier rôle et accès', 'Edit role & access'))),
                    PopupMenuItem<String>(
                        value: 'toggle',
                        child: Text(member.isActive
                            ? ctr(context, 'Pause', 'Dakatar', 'Mettre en pause', 'Pause')
                            : ctr(context, 'Reactivate', 'Sake kunnawa', 'Réactiver', 'Reactivate'))),
                    PopupMenuItem<String>(
                        value: 'remove',
                        child: Text(ctr(context, 'Remove', 'Cire', 'Retirer', 'Remove'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _chip(_roleText(context, member.role), color),
                _chip(_financeText(context, member.financeAccess),
                    theme.colorScheme.onSurfaceVariant),
                _chip(status,
                    member.isActive ? const Color(0xFF2E9E5B) : const Color(0xFFD99A1E)),
                if (member.hasScopedRecordAccess)
                  _chip(
                      ctr(context, '${member.allowedCropIds.length} crops · ${member.allowedLivestockIds.length} animal groups', '${member.allowedCropIds.length} amfanin gona · ${member.allowedLivestockIds.length} rukunin dabbobi', '${member.allowedCropIds.length} cultures · ${member.allowedLivestockIds.length} groupes d’animaux', '${member.allowedCropIds.length} crops · ${member.allowedLivestockIds.length} animal groups'),
                      const Color(0xFF0EA5A4)),
              ],
            ),
            if (perms.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('${ctr(context, 'Can', 'Zai iya', 'Peut', 'E fit')}: ${perms.join(' · ')}',
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

  String _label(FarmFinanceAccess a) => _financeText(context, a);

  String _roleLabel(FarmWorkspaceRole r) => _roleText(context, r);

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = ctr(context, 'Enter the member’s name.', 'Shigar da sunan memba.', 'Saisissez le nom du membre.', 'Put the member name.'));
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
                Text(
                    widget.existing == null
                        ? ctr(context, 'Add member', 'Kara memba', 'Ajouter un membre', 'Add member')
                        : ctr(context, 'Edit member', 'Gyara memba', 'Modifier le membre', 'Edit member'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: ctr(context, 'Full name', 'Cikakken suna', 'Nom complet', 'Full name'),
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: ctr(context, 'Email (to invite them to the app)', 'Imel (don gayyatarsu zuwa manhajar)', 'E-mail (pour les inviter dans l’app)', 'Email (to invite dem to the app)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: ctr(context, 'Phone (optional)', 'Waya (ba dole ba)', 'Téléphone (facultatif)', 'Phone (optional)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(ctr(context, 'Role', 'Matsayi', 'Rôle', 'Role'), style: theme.textTheme.labelLarge),
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
                  decoration: InputDecoration(
                      labelText: ctr(context, 'Finance access', 'Damar kudi', 'Accès aux finances', 'Access to money records'),
                      border: const OutlineInputBorder()),
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
                  title: Text(ctr(context, 'Can manage tasks', 'Zai iya sarrafa ayyuka', 'Peut gérer les tâches', 'E fit manage tasks')),
                  value: _tasks,
                  onChanged: (bool v) => setState(() => _tasks = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctr(context, 'Can manage schedule', 'Zai iya sarrafa jadawali', 'Peut gérer le calendrier', 'E fit manage schedule')),
                  value: _schedule,
                  onChanged: (bool v) => setState(() => _schedule = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctr(context, 'Can post updates', 'Zai iya sanya sabuntawa', 'Peut publier des mises à jour', 'E fit post updates')),
                  value: _updates,
                  onChanged: (bool v) => setState(() => _updates = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctr(context, 'Can view activity log', 'Zai iya duba rajistar ayyuka', 'Peut voir le journal d’activité', 'E fit see activity log')),
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
                          ? ctr(context, 'Add to team', 'Kara a ƙungiya', 'Ajouter à l’équipe', 'Add to team')
                          : ctr(context, 'Save changes', 'Adana canje-canje', 'Enregistrer les modifications', 'Save changes')),
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
