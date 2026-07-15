import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/finance_report_service.dart';
import '../../../core/services/report_file_saver.dart';
import '../../../core/services/report_file_saver_base.dart';
import '../../../core/services/report_share_service.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../core/utils/validators.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import 'market_trends_screen.dart';
import 'finance_workspace_screen.dart';
import 'finance_ai_recap_screen.dart';
import '../sales/sales_desk_screen.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/widgets/farm_scene_artwork.dart';
import '../../common/widgets/soft_screen_scaffold.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final FinanceReportService _reportService = FinanceReportService();
  final ReportFileSaver _fileSaver = createReportFileSaver();
  final ReportShareService _shareService = const ReportShareService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final FinanceSnapshot snapshot = FinanceSnapshot.fromTransactions(transactions);
    final List<Transaction> sales = transactions
        .where((Transaction item) => item.recordKind == TransactionRecordKind.sale)
        .toList(growable: false);
    final List<Transaction> procurement = transactions
        .where((Transaction item) => item.recordKind == TransactionRecordKind.procurement)
        .toList(growable: false);
    final List<Transaction> recentActivities = transactions.toList(growable: false)
      ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));
    final List<Transaction> topRecentActivities = recentActivities.take(6).toList(growable: false);

    return SoftScreenScaffold(
      onBack: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/dashboard'),
      heroTitle: language.tr(
        en: 'Finance command center',
        ha: 'Cibiyar harkokin kudi',
        fr: 'Centre financier',
      ),
      heroSubtitle: language.tr(
        en: 'Jump into dedicated sales, expense, and procurement screens, then review recent activity and export polished reports.',
        ha: 'Shiga cikin allon siyarwa, kashe kudi, da sayen kaya na musamman, sannan duba sabbin ayyuka da fitar da rahotanni masu kyau.',
        fr: 'Accédez aux écrans dédiés des ventes, dépenses et achats, puis consultez l activité récente et exportez des rapports soignés.',
      ),
      heroIcon: Icons.point_of_sale_rounded,
      heroVariant: FarmArtworkVariant.finance,
      heroBadge: language.tr(
        en: '${farms.length} farms - ${sales.length} sales - ${procurement.length} procurement',
        ha: '${farms.length} gonaki - ${sales.length} siyarwa - ${procurement.length} saye',
        fr: '${farms.length} fermes - ${sales.length} ventes - ${procurement.length} achats',
      ),
      
      showArtwork: true,
      sections: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth > 720 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 4 ? 1.35 : 1.15,
              children: <Widget>[
                _ActionTile(
                  label: language.tr(en: 'Open workspace', ha: 'Bude wurin aiki', fr: 'Ouvrir l espace'),
                  subtitle: language.tr(en: 'Workspace overview', ha: 'Jigon wurin aiki', fr: 'Vue d ensemble'),
                  icon: Icons.grid_view_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinanceWorkspaceScreen(),
                    ),
                  ),
                ),
                _ActionTile(
                  label: language.tr(en: 'Sales desk', ha: 'Wurin siyarwa', fr: 'Bureau des ventes'),
                  subtitle: language.tr(en: 'Record sales fast', ha: 'Rubuta siyarwa da sauri', fr: 'Ventes rapides'),
                  icon: Icons.point_of_sale_rounded,
                  onTap: () => context.go(SalesDeskScreen.routeName),
                ),
                _ActionTile(
                  label: language.tr(en: 'Expense tracking', ha: 'Bibiyar kashe kudi', fr: 'Suivi des dépenses'),
                  subtitle: language.tr(en: 'Log costs', ha: 'Rubuta kashe', fr: 'Suivre les coûts'),
                  icon: Icons.receipt_long_outlined,
                  onTap: () => context.go('/expenses'),
                ),
                _ActionTile(
                  label: language.tr(en: 'Procurement', ha: 'Siyayya', fr: 'Approvisionnement'),
                  subtitle: language.tr(en: 'Buy inputs', ha: 'Sayi kayan shuka', fr: 'Achats intrants'),
                  icon: Icons.shopping_cart_outlined,
                  onTap: () => context.go('/procurement'),
                ),
                _ActionTile(
                  label: language.tr(en: 'Sales analytics', ha: 'Nazarin siyarwa', fr: 'Analyses ventes'),
                  subtitle: language.tr(en: 'View performance', ha: 'Duba yi', fr: 'Voir les performances'),
                  icon: Icons.insights_rounded,
                  onTap: () => context.go('/sales-info'),
                ),
                _ActionTile(
                  label: language.tr(en: 'AI recap', ha: 'Takaitaccen AI', fr: 'Résumé IA'),
                  subtitle: language.tr(en: 'Smart finance summary', ha: 'Takaitaccen kudi', fr: 'Résumé intelligent'),
                  icon: Icons.auto_awesome_rounded,
                  onTap: () => context.go(FinanceAiRecapScreen.routeName),
                ),
                _ActionTile(
                  label: language.tr(en: 'Export finance PDF', ha: 'Fitar da PDF', fr: 'Exporter PDF'),
                  subtitle: language.tr(en: 'Share the report', ha: 'Raba rahoto', fr: 'Partager le rapport'),
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: _isExporting || transactions.isEmpty ? null : () => _exportReport(snapshot, transactions),
                ),
                _ActionTile(
                  label: language.tr(en: 'Market trends', ha: 'Yanayin kasuwa', fr: 'Tendances'),
                  subtitle: language.tr(en: 'Track demand', ha: 'Bi bukata', fr: 'Suivre le marché'),
                  icon: Icons.show_chart_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MarketTrendsScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: SoftInfoChip(
                label: language.tr(en: 'Income', ha: 'Shiga kudi', fr: 'Revenus'),
                value: CurrencyUtils.formatCompactCurrency(snapshot.income),
                color: const Color(0xFFE5F5D8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: language.tr(en: 'Expenses', ha: 'Fito kudi', fr: 'Dépenses'),
                value: CurrencyUtils.formatCompactCurrency(snapshot.expenses),
                color: const Color(0xFFFFE7D7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: language.tr(en: 'Open balance', ha: 'Ragowar kudi', fr: 'Solde'),
                value: CurrencyUtils.formatCompactCurrency(snapshot.balance),
                color: const Color(0xFFDFF1FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftInfoChip(
                label: language.tr(en: 'Recent items', ha: 'Sabbin abubuwa', fr: 'Récents'),
                value: topRecentActivities.length.toString(),
                color: const Color(0xFFFFEBCF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: language.tr(en: 'Dedicated modules', ha: 'Sassan aiki na musamman', fr: 'Modules dédiés'),
        ),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: AppButton.primary(
                    onPressed: () => context.go(SalesDeskScreen.routeName),
                    child: const Text('Open sales desk'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AppButton.secondary(
                    onPressed: () => context.go('/expenses'),
                    child: const Text('Open expense tracker'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AppButton.secondary(
                    onPressed: () => context.go('/procurement'),
                    child: const Text('Open procurement'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AppButton.secondary(
                    onPressed: transactions.isEmpty ? null : () => _exportReport(snapshot, transactions),
                    child: const Text('Export finance report'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: language.tr(en: 'Recent activity', ha: 'Sabbin ayyuka', fr: 'Activité récente'),
        ),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  language.tr(
                    en: 'Recent finance activity reflects sales, expenses, and procurement recorded across the app.',
                    ha: 'Sabbin ayyukan kudi suna nuna siyarwa, kashe kudi, da sayen kaya da aka rubuta a cikin app.',
                    fr: 'L activité financière récente reflète les ventes, dépenses et achats enregistrés dans l application.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                if (topRecentActivities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No recent transactions yet.'),
                  )
                else
                  ...topRecentActivities.map(
                    (Transaction transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TransactionRecordTile(
                        transaction: transaction,
                        onTap: () => _openReceiptDetail(context, transaction),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SoftSectionTitle(
          title: language.tr(en: 'Dedicated reports', ha: 'Rahotanni na musamman', fr: 'Rapports dédiés'),
        ),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth > 720 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 4 ? 1.35 : 1.15,
                  children: <Widget>[
                    _ActionTile(
                      label: language.tr(en: 'Sales analytics', ha: 'Nazarin siyarwa', fr: 'Analyses ventes'),
                      subtitle: language.tr(en: 'View performance', ha: 'Duba yi', fr: 'Voir les performances'),
                      icon: Icons.insights_rounded,
                      onTap: () => context.go('/sales-info'),
                    ),
                    _ActionTile(
                      label: language.tr(en: 'Expense report', ha: 'Rahoton kashe kudi', fr: 'Rapport dépenses'),
                      subtitle: language.tr(en: 'Track costs', ha: 'Bi kashe', fr: 'Suivre les coûts'),
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.go('/expenses'),
                    ),
                    _ActionTile(
                      label: language.tr(en: 'Procurement report', ha: 'Rahoton saye', fr: 'Rapport achats'),
                      subtitle: language.tr(en: 'Review purchases', ha: 'Duba sayayya', fr: 'Examiner achats'),
                      icon: Icons.shopping_cart_outlined,
                      onTap: () => context.go('/procurement'),
                    ),
                    _ActionTile(
                      label: language.tr(en: 'Market trends', ha: 'Yanayin kasuwa', fr: 'Tendances'),
                      subtitle: language.tr(en: 'Track demand', ha: 'Bi bukata', fr: 'Suivre le marché'),
                      icon: Icons.show_chart_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MarketTrendsScreen(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportReport(FinanceSnapshot snapshot, List<Transaction> transactions) async {
    setState(() => _isExporting = true);
    try {
      final String fileName = 'farmsync_finance_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await _reportService.buildFinanceReport(
        transactions: transactions,
        income: snapshot.income,
        expenses: snapshot.expenses,
        balance: snapshot.balance,
        categoryTotals: snapshot.categoryTotals,
      );
      final String savedPath = await _fileSaver.savePdf(
        bytes: bytes,
        fileName: fileName,
      );
      await _shareService.sharePdf(
        filePath: savedPath,
        fileName: fileName,
        message: 'FarmSync finance report is ready to share.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported: $savedPath')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _openPartnerSheet(BuildContext context) async {
    final _PartnerDraft? draft = await showModalBottomSheet<_PartnerDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const _PartnerSheet(),
    );
    if (draft == null) {
      return;
    }
    await ref.read(operationsHubProvider.notifier).addPartner(
          BusinessPartner(
            id: const Uuid().v4(),
            name: draft.name,
            email: draft.email,
            phone: draft.phone,
            type: draft.type,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _openInventorySheet(BuildContext context, List<Farm> farms) async {
    final _InventoryDraft? draft = await showModalBottomSheet<_InventoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _InventorySheet(farms: farms),
    );
    if (draft == null) {
      return;
    }
    await ref.read(operationsHubProvider.notifier).addInventoryItem(
          InventoryItem(
            id: const Uuid().v4(),
            farmId: draft.farmId,
            name: draft.name,
            category: draft.category,
            unit: draft.unit,
            availableQuantity: draft.quantity,
            costPrice: draft.costPrice,
            unitPrice: draft.unitPrice,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _openTransactionSheet(BuildContext context, {required List<Farm> farms}) async {
    final OperationsHubState operations = ref.read(operationsHubProvider);
    final _TransactionDraft? draft = await showModalBottomSheet<_TransactionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TransactionFormSheet(
        farms: farms,
        operations: operations,
      ),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final Transaction transaction = Transaction(
      id: const Uuid().v4(),
      farmId: draft.farmId,
      type: draft.type,
      category: draft.category,
      amount: draft.amount,
      description: draft.description,
      transactionDate: draft.transactionDate,
      linkedEntityId: draft.partnerId,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
      recordKind: draft.recordKind,
      partyType: draft.partyType,
      productName: draft.productName,
      quantity: draft.quantity,
      unit: draft.unit,
      unitPrice: draft.unitPrice,
      counterpartyName: draft.counterpartyName,
      counterpartyEmail: draft.counterpartyEmail,
      counterpartyPhone: draft.counterpartyPhone,
      receiptNumber: 'FS-${DateTime.now().millisecondsSinceEpoch}',
      notes: draft.notes,
    );
    await ref.read(transactionsProvider.notifier).addTransaction(transaction);

    final double delta = draft.recordKind == TransactionRecordKind.sale
        ? -draft.quantity
        : draft.recordKind == TransactionRecordKind.procurement
            ? draft.quantity
            : 0;
    if (delta != 0 && draft.productName.trim().isNotEmpty) {
      await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
            farmId: draft.farmId,
            productName: draft.productName,
            unit: draft.unit,
            deltaQuantity: delta,
            unitPrice: draft.unitPrice,
          );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          draft.recordKind == TransactionRecordKind.sale
              ? 'Sale recorded and receipt generated.'
              : draft.recordKind == TransactionRecordKind.procurement
                  ? 'Procurement recorded successfully.'
                  : 'Transaction recorded successfully.',
        ),
      ),
    );
  }

  void _openReceiptDetail(BuildContext context, Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(transaction: transaction),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isEnabled = onTap != null;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = theme.colorScheme.primary;
    final Color panelColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: panelColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? <Color>[theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainer]
                  : <Color>[theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerLow],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isEnabled ? theme.colorScheme.onSurface : theme.disabledColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled ? theme.colorScheme.onSurfaceVariant : theme.disabledColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({
    super.key,
    required this.transaction,
  });

  final Transaction transaction;

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final Transaction transaction = widget.transaction;
    final Farm? farm = ref.watch(farmsProvider).valueOrNull?.firstWhere(
          (Farm item) => item.id == transaction.farmId,
          orElse: () => Farm(
            id: '',
            name: 'Unknown farm',
            ward: '',
            sizeHa: 0,
            farmType: FarmType.combined,
            farmerCategory: FarmerCategory.subsistence,
            soilType: SoilType.loamy,
            waterSource: WaterSource.rainfall,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isSynced: true,
          ),
        );
    final String sellerEmail = ref.watch(firebaseServiceProvider).currentUser?.email ?? '';
    final String sellerName = ref.watch(firebaseServiceProvider).currentUser?.displayName ?? 'FarmSync Seller';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          transaction.recordKind == TransactionRecordKind.procurement
              ? 'Procurement Detail'
              : 'Receipt Detail',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isExporting
                ? null
                : () => _exportReceipt(
                      transaction: transaction,
                      farmName: farm?.name ?? 'Farm',
                      sellerName: sellerName,
                    ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF',
          ),
          IconButton(
            onPressed: _isExporting ? null : _exportReceiptImage,
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Export image',
          ),
          IconButton(
            onPressed: () => _composeEmail(
              buyerEmail: transaction.counterpartyEmail,
              sellerEmail: sellerEmail,
              receiptNumber: transaction.receiptNumber,
              total: transaction.amount,
            ),
            icon: const Icon(Icons.email_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            RepaintBoundary(
              key: _receiptBoundaryKey,
              child: _ReceiptPreviewCard(
                transaction: transaction,
                farmName: farm?.name ?? 'Farm',
                sellerName: sellerName,
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Export options',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A styled receipt preview is available here. PDF export is supported directly from this screen, and email handoff pre-fills buyer and seller details when an email address is present.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReceipt({
    required Transaction transaction,
    required String farmName,
    required String sellerName,
  }) async {
    setState(() => _isExporting = true);
    try {
      final Uint8List bytes = await FinanceReportService().buildSalesReceipt(
        transaction: transaction,
        farmName: farmName,
        sellerName: sellerName,
      );
      final String path = await createReportFileSaver().savePdf(
        bytes: bytes,
        fileName: 'receipt_${transaction.receiptNumber.isEmpty ? transaction.id : transaction.receiptNumber}.pdf',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt exported: $path')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportReceiptImage() async {
    setState(() => _isExporting = true);
    try {
      final RenderRepaintBoundary? boundary =
          _receiptBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Receipt preview is not ready yet.');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Could not render receipt image.');
      }
      final Uint8List bytes = byteData.buffer.asUint8List();
      final String path = await createReportFileSaver().saveBytes(
        bytes: bytes,
        fileName: 'receipt_${widget.transaction.receiptNumber.isEmpty ? widget.transaction.id : widget.transaction.receiptNumber}.png',
        mimeType: 'image/png',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt image exported: $path')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _composeEmail({
    required String buyerEmail,
    required String sellerEmail,
    required String receiptNumber,
    required double total,
  }) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: buyerEmail.isEmpty ? sellerEmail : buyerEmail,
      queryParameters: <String, String>{
        if (sellerEmail.isNotEmpty && buyerEmail.isNotEmpty) 'cc': sellerEmail,
        'subject': 'FarmSync Receipt $receiptNumber',
        'body': 'Receipt number: $receiptNumber\nTotal: ${CurrencyUtils.formatCurrency(total)}',
      },
    );
    await launchUrl(uri);
  }
}

class _ReceiptPreviewCard extends StatelessWidget {
  const _ReceiptPreviewCard({
    required this.transaction,
    required this.farmName,
    required this.sellerName,
  });

  final Transaction transaction;
  final String farmName;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F5D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        transaction.recordKind == TransactionRecordKind.procurement
                            ? 'Procurement Record'
                            : 'Sales Receipt',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(transaction.receiptNumber),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(transaction.amount),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ReceiptLine(label: 'Farm', value: farmName),
            _ReceiptLine(label: 'Seller', value: sellerName),
            _ReceiptLine(
              label: transaction.recordKind == TransactionRecordKind.procurement ? 'Provider' : 'Buyer',
              value: transaction.counterpartyName.isEmpty ? 'Walk-in' : transaction.counterpartyName,
            ),
            _ReceiptLine(
              label: 'Product',
              value: transaction.productName.isEmpty ? transaction.description : transaction.productName,
            ),
            _ReceiptLine(
              label: 'Quantity',
              value: '${transaction.quantity.toStringAsFixed(2)} ${transaction.unit}',
            ),
            _ReceiptLine(
              label: 'Unit price',
              value: CurrencyUtils.formatCurrency(transaction.unitPrice),
            ),
            _ReceiptLine(
              label: 'Date',
              value: app_date.DateUtils.formatDate(transaction.transactionDate),
            ),
            if (transaction.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                transaction.notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRecordTile extends StatelessWidget {
  const _TransactionRecordTile({
    required this.transaction,
    required this.onTap,
  });

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool positive = transaction.type == TransactionType.income;

    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: positive ? const Color(0xFFE5F5D8) : const Color(0xFFFFEBD0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            positive ? Icons.trending_up_rounded : Icons.shopping_bag_outlined,
          ),
        ),
        title: Text(transaction.productName.isEmpty ? transaction.description : transaction.productName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${transaction.counterpartyName.isEmpty ? 'Walk-in' : transaction.counterpartyName} - ${app_date.DateUtils.formatDate(transaction.transactionDate)}\n${transaction.quantity.toStringAsFixed(2)} ${transaction.unit}',
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(CurrencyUtils.formatCurrency(transaction.amount)),
            const SizedBox(height: 4),
            Text(
              transaction.recordKind == TransactionRecordKind.sale ? 'Receipt' : 'View',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFinanceCard extends StatelessWidget {
  const _EmptyFinanceCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message),
      ),
    );
  }
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.categoryTotals,
  });

  final double income;
  final double expenses;
  final double balance;
  final Map<TransactionCategory, double> categoryTotals;

  factory FinanceSnapshot.fromTransactions(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    final Map<TransactionCategory, double> categoryTotals = <TransactionCategory, double>{};
    for (final Transaction transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
      categoryTotals.update(
        transaction.category,
        (double value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return FinanceSnapshot(
      income: income,
      expenses: expenses,
      balance: income - expenses,
      categoryTotals: categoryTotals,
    );
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    required this.farms,
    required this.operations,
  });

  final List<Farm> farms;
  final OperationsHubState operations;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _unitController = TextEditingController(text: 'bag');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _farmId;
  TransactionRecordKind _recordKind = TransactionRecordKind.sale;
  TransactionCategory _category = TransactionCategory.cropSale;
  final DateTime _transactionDate = DateTime.now();
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<BusinessPartner> partners = widget.operations.partners
        .where((BusinessPartner item) {
          if (_recordKind == TransactionRecordKind.sale) {
            return item.type == BusinessPartnerType.customer;
          }
          if (_recordKind == TransactionRecordKind.procurement) {
            return item.type == BusinessPartnerType.provider;
          }
          return true;
        })
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Record sale or procurement', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                _DropdownField<String>(
                  label: 'Farm',
                  value: _farmId,
                  items: widget.farms.map((Farm farm) => farm.id).toList(),
                  itemLabel: (String value) => widget.farms.firstWhere((Farm farm) => farm.id == value).name,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _farmId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _DropdownField<TransactionRecordKind>(
                  label: 'Record type',
                  value: _recordKind,
                  items: const <TransactionRecordKind>[
                    TransactionRecordKind.sale,
                    TransactionRecordKind.procurement,
                    TransactionRecordKind.general,
                  ],
                  itemLabel: (TransactionRecordKind value) {
                    switch (value) {
                      case TransactionRecordKind.sale:
                        return 'Sale';
                      case TransactionRecordKind.procurement:
                        return 'Procurement';
                      case TransactionRecordKind.general:
                        return 'General';
                    }
                  },
                  onChanged: (TransactionRecordKind? value) {
                    if (value != null) {
                      setState(() {
                        _recordKind = value;
                        _category = value == TransactionRecordKind.procurement
                            ? TransactionCategory.other
                            : TransactionCategory.cropSale;
                        _partnerId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (partners.isNotEmpty)
                  _DropdownField<String?>(
                    label: _recordKind == TransactionRecordKind.procurement ? 'Provider' : 'Customer',
                    value: _partnerId,
                    items: <String?>[null, ...partners.map((BusinessPartner item) => item.id)],
                    itemLabel: (String? value) {
                      if (value == null) {
                        return 'Walk-in / unregistered';
                      }
                      return partners.firstWhere((BusinessPartner item) => item.id == value).name;
                    },
                    onChanged: (String? value) => setState(() => _partnerId = value),
                  ),
                if (partners.isNotEmpty) const SizedBox(height: 12),
                AppTextField(controller: _productController, label: 'Product', hint: 'Maize, eggs, feed'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        controller: _quantityController,
                        label: 'Quantity',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(controller: _unitController, label: 'Unit', hint: 'bag, crate, kg'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _unitPriceController,
                        label: 'Unit price',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _amountController,
                  label: 'Total amount',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Market sale or farm supply note',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _notesController,
                  label: 'Receipt notes',
                  hint: 'Delivery details, payment note, or stock observation',
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        onPressed: () => _submit(partners),
                        child: const Text('Save'),
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

  void _submit(List<BusinessPartner> partners) {
    final String? amountError = Validators.combine(
      <String? Function(String?)>[
        (String? value) => Validators.required(value, fieldName: 'Total amount'),
        Validators.amount,
      ],
      _amountController.text.trim(),
    );
    if (amountError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(amountError)));
      return;
    }

    final BusinessPartner? partner = _partnerId == null
        ? null
        : partners.firstWhere((BusinessPartner item) => item.id == _partnerId);
    final TransactionType type = _recordKind == TransactionRecordKind.procurement
        ? TransactionType.expense
        : TransactionType.income;

    Navigator.of(context).pop(
      _TransactionDraft(
        farmId: _farmId,
        type: type,
        category: _recordKind == TransactionRecordKind.procurement
            ? TransactionCategory.other
            : _productController.text.trim().toLowerCase().contains('livestock')
                ? TransactionCategory.livestockSale
                : TransactionCategory.cropSale,
        amount: double.parse(_amountController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? _productController.text.trim()
            : _descriptionController.text.trim(),
        transactionDate: _transactionDate,
        recordKind: _recordKind,
        partyType: _recordKind == TransactionRecordKind.procurement
            ? TransactionPartyType.provider
            : TransactionPartyType.customer,
        productName: _productController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
        counterpartyName: partner?.name ?? '',
        counterpartyEmail: partner?.email ?? '',
        counterpartyPhone: partner?.phone ?? '',
        partnerId: partner?.id ?? '',
        notes: _notesController.text.trim(),
      ),
    );
  }
}

class _InventorySheet extends StatefulWidget {
  const _InventorySheet({required this.farms});

  final List<Farm> farms;

  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Farm produce');
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: 'bag');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  late String _farmId;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _DropdownField<String>(
              label: 'Farm',
              value: _farmId,
              items: widget.farms.map((Farm farm) => farm.id).toList(),
              itemLabel: (String value) => widget.farms.firstWhere((Farm item) => item.id == value).name,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _farmId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _nameController, label: 'Product name'),
            const SizedBox(height: 12),
            AppTextField(controller: _categoryController, label: 'Category'),
            const SizedBox(height: 12),
            AppTextField(controller: _quantityController, label: 'Available quantity'),
            const SizedBox(height: 12),
            AppTextField(controller: _unitController, label: 'Unit'),
            const SizedBox(height: 12),
            AppTextField(controller: _costPriceController, label: 'Cost price'),
            const SizedBox(height: 12),
            AppTextField(controller: _unitPriceController, label: 'Selling price'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: const Text('Save inventory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _InventoryDraft(
        farmId: _farmId,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
        unit: _unitController.text.trim(),
        costPrice: double.tryParse(_costPriceController.text.trim()) ?? 0,
        unitPrice: double.tryParse(_unitPriceController.text.trim()) ?? 0,
      ),
    );
  }
}

class _PartnerSheet extends StatefulWidget {
  const _PartnerSheet();

  @override
  State<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends State<_PartnerSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  BusinessPartnerType _type = BusinessPartnerType.customer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppTextField(controller: _nameController, label: 'Name'),
            const SizedBox(height: 12),
            AppTextField(controller: _emailController, label: 'Email'),
            const SizedBox(height: 12),
            AppTextField(controller: _phoneController, label: 'Phone'),
            const SizedBox(height: 12),
            _DropdownField<BusinessPartnerType>(
              label: 'Contact type',
              value: _type,
              items: BusinessPartnerType.values,
              itemLabel: (BusinessPartnerType value) =>
                  value == BusinessPartnerType.customer ? 'Customer' : 'Provider',
              onChanged: (BusinessPartnerType? value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                onPressed: _submit,
                child: const Text('Save contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _PartnerDraft(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        type: _type,
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TransactionDraft {
  const _TransactionDraft({
    required this.farmId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.recordKind,
    required this.partyType,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.counterpartyName,
    required this.counterpartyEmail,
    required this.counterpartyPhone,
    required this.partnerId,
    required this.notes,
  });

  final String farmId;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final TransactionRecordKind recordKind;
  final TransactionPartyType partyType;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String counterpartyName;
  final String counterpartyEmail;
  final String counterpartyPhone;
  final String partnerId;
  final String notes;
}

class _PartnerDraft {
  const _PartnerDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
  });

  final String name;
  final String email;
  final String phone;
  final BusinessPartnerType type;
}

class _InventoryDraft {
  const _InventoryDraft({
    required this.farmId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.unitPrice,
  });

  final String farmId;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double costPrice;
  final double unitPrice;
}
