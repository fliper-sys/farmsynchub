import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../domain/models/farm.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user_profile.dart';
import '../../../providers/farm_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/operations_hub_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';
import '../../common/widgets/app_text_field.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InventoryItem> inventory = ref.watch(operationsHubProvider).inventory;
    final InventoryItem? item = _findItem(inventory, productId);
    final List<Farm> farms = ref.watch(farmsProvider).valueOrNull ?? <Farm>[];
    final List<Transaction> transactions = ref.watch(transactionsProvider).valueOrNull ?? <Transaction>[];
    final UserProfile? profile = ref.watch(userProfileProvider).valueOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: const Center(child: Text('Product not found.')),
      );
    }

    final List<Transaction> sales = _historyForProduct(
      transactions,
      item,
      kind: TransactionRecordKind.sale,
    );
    final List<Transaction> procurements = _historyForProduct(
      transactions,
      item,
      kind: TransactionRecordKind.procurement,
    );
    final bool isOwner = profile?.accountRole == UserAccountRole.owner;
    final double stockValue = item.availableQuantity * item.unitPrice;
    final double costValue = item.availableQuantity * item.costPrice;
    final double marginPerUnit = item.unitPrice - item.costPrice;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit product',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _openEditSheet(context, ref, item),
          ),
          if (isOwner)
            IconButton(
              tooltip: 'Delete product',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context, ref, item),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4D8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(item.emoji, style: const TextStyle(fontSize: 30)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              '${item.category} - ${_farmName(farms, item.farmId)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetaChip(text: '${item.availableQuantity.toStringAsFixed(2)} ${item.unit} in stock'),
                      _MetaChip(text: 'Sell: ${CurrencyUtils.formatCurrency(item.unitPrice)}'),
                      _MetaChip(text: 'Cost: ${CurrencyUtils.formatCurrency(item.costPrice)}'),
                      _MetaChip(text: 'Margin: ${CurrencyUtils.formatCurrency(marginPerUnit)}'),
                      _MetaChip(text: 'Stock value: ${CurrencyUtils.formatCurrency(stockValue)}'),
                      _MetaChip(text: 'Cost basis: ${CurrencyUtils.formatCurrency(costValue)}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selling price and purchase cost can be edited here so the product history stays meaningful.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.primary(
                  onPressed: () => _openProcurementSheet(context, ref, item),
                  child: const Text('Add procurement'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.secondary(
                  onPressed: () => _openEditSheet(context, ref, item),
                  child: const Text('Edit product'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Sales history'),
          if (sales.isEmpty)
            const _EmptyMessage(message: 'No sales linked to this product yet.')
          else
            ...sales.map(
              (Transaction sale) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TransactionTile(transaction: sale),
              ),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Procurement history'),
          if (procurements.isEmpty)
            const _EmptyMessage(message: 'No procurement entries linked to this product yet.')
          else
            ...procurements.map(
              (Transaction procurement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TransactionTile(transaction: procurement, showAttachments: true),
              ),
            ),
        ],
      ),
    );
  }

  InventoryItem? _findItem(List<InventoryItem> inventory, String productId) {
    for (final InventoryItem item in inventory) {
      if (item.id == productId) {
        return item;
      }
    }
    return null;
  }

  List<Transaction> _historyForProduct(
    List<Transaction> transactions,
    InventoryItem item, {
    required TransactionRecordKind kind,
  }) {
    final String normalizedName = item.name.trim().toLowerCase();
    return transactions
        .where((Transaction transaction) => transaction.recordKind == kind)
        .where((Transaction transaction) =>
            transaction.linkedEntityId == item.id ||
            transaction.productName.trim().toLowerCase() == normalizedName)
        .toList(growable: false)
      ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));
  }

  String _farmName(List<Farm> farms, String farmId) {
    for (final Farm farm in farms) {
      if (farm.id == farmId) {
        return farm.name;
      }
    }
    return 'Unknown farm';
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final _ProductEditDraft? draft = await showModalBottomSheet<_ProductEditDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductEditSheet(item: item),
    );
    if (draft == null) {
      return;
    }

    await ref.read(operationsHubProvider.notifier).updateInventoryItem(
          item.copyWith(
            name: draft.name,
            category: draft.category,
            unit: draft.unit,
            unitPrice: draft.sellingPrice,
            costPrice: draft.costPrice,
            emoji: draft.emoji,
            updatedAt: DateTime.now(),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete product?'),
          content: Text(
            'This removes "${item.name}" from the active stock list. Its sales and procurement history will remain in the finance records.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(operationsHubProvider.notifier).deleteInventoryItem(item.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted.')),
      );
    }
  }

  Future<void> _openProcurementSheet(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final _ProductProcurementDraft? draft = await showModalBottomSheet<_ProductProcurementDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductProcurementSheet(item: item),
    );
    if (draft == null) {
      return;
    }

    final DateTime now = DateTime.now();
    await ref.read(operationsHubProvider.notifier).adjustInventoryQuantity(
          farmId: item.farmId,
          productName: item.name,
          unit: item.unit,
          deltaQuantity: draft.quantity,
          unitPrice: item.unitPrice,
          costPrice: draft.costPrice,
        );
    await ref.read(transactionsProvider.notifier).addTransaction(
          Transaction(
            id: const Uuid().v4(),
            farmId: item.farmId,
            type: TransactionType.expense,
            category: draft.category,
            amount: draft.quantity * draft.costPrice,
            description: draft.description.isEmpty ? '${item.name} procurement' : draft.description,
            transactionDate: now,
            linkedEntityId: item.id,
            createdAt: now,
            updatedAt: now,
            isSynced: true,
            recordKind: TransactionRecordKind.procurement,
            partyType: TransactionPartyType.provider,
            productName: item.name,
            quantity: draft.quantity,
            unit: item.unit,
            unitPrice: draft.costPrice,
            counterpartyName: draft.vendorName,
            counterpartyEmail: draft.vendorEmail,
            counterpartyPhone: draft.vendorPhone,
            receiptNumber: 'PR-${now.millisecondsSinceEpoch}',
            notes: draft.notes,
            attachmentNames: draft.attachmentNames,
            attachmentBase64: draft.attachmentBase64,
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Procurement added and stock updated.')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    this.showAttachments = false,
  });

  final Transaction transaction;
  final bool showAttachments;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = transaction.recordKind == TransactionRecordKind.sale
        ? const Color(0xFFE5F5D8)
        : const Color(0xFFFFE7D7);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color iconBackground = isDark ? Color.alphaBlend(tint.withOpacity(0.22), theme.colorScheme.surface) : tint;
    final Color iconForeground = isDark ? theme.colorScheme.onSurface : AppColors.primary;

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? tint.withOpacity(0.42) : Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    transaction.recordKind == TransactionRecordKind.sale
                        ? Icons.payments_outlined
                        : Icons.receipt_long_outlined,
                    color: iconForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        transaction.description,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app_date.DateUtils.formatDate(transaction.transactionDate)} • ${transaction.receiptNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(transaction.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaChip(text: '${transaction.quantity.toStringAsFixed(2)} ${transaction.unit}'),
                _MetaChip(text: CurrencyUtils.formatCurrency(transaction.unitPrice)),
                if (transaction.counterpartyName.isNotEmpty) _MetaChip(text: transaction.counterpartyName),
              ],
            ),
            if (transaction.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(transaction.notes, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
            ],
            if (showAttachments && transaction.attachmentBase64.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(transaction.attachmentBase64.length, (int index) {
                  final String name = index < transaction.attachmentNames.length
                      ? transaction.attachmentNames[index]
                      : 'Attachment ${index + 1}';
                  final String lower = name.toLowerCase();
                  final IconData icon = lower.endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded;
                  return Chip(
                    avatar: Icon(icon, size: 18),
                    label: Text(name),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductEditSheet extends StatefulWidget {
  const _ProductEditSheet({required this.item});

  final InventoryItem item;

  @override
  State<_ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<_ProductEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;
  late String _emoji;

  static const List<String> _emojiOptions = <String>[
    '🌾',
    '🥬',
    '🍅',
    '🌽',
    '🥚',
    '🥛',
    '🐐',
    '🐟',
    '🧪',
    '🍎',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _categoryController = TextEditingController(text: widget.item.category);
    _unitController = TextEditingController(text: widget.item.unit);
    _costController = TextEditingController(text: widget.item.costPrice.toStringAsFixed(2));
    _sellingController = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
    _emoji = widget.item.emoji;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _sellingController.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(controller: _nameController, label: 'Product name'),
              const SizedBox(height: 12),
              AppTextField(controller: _categoryController, label: 'Category'),
              const SizedBox(height: 12),
              AppTextField(controller: _unitController, label: 'Unit'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: AppTextField(controller: _costController, label: 'Cost price', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _sellingController, label: 'Selling price', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojiOptions
                    .map(
                      (String emoji) => ChoiceChip(
                        label: Text(emoji),
                        selected: _emoji == emoji,
                        onSelected: (_) => setState(() => _emoji = emoji),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _ProductEditDraft(
                        name: _nameController.text.trim(),
                        category: _categoryController.text.trim(),
                        unit: _unitController.text.trim().isEmpty ? 'unit' : _unitController.text.trim(),
                        costPrice: double.tryParse(_costController.text.trim()) ?? 0,
                        sellingPrice: double.tryParse(_sellingController.text.trim()) ?? 0,
                        emoji: _emoji,
                      ),
                    );
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductEditDraft {
  const _ProductEditDraft({
    required this.name,
    required this.category,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.emoji,
  });

  final String name;
  final String category;
  final String unit;
  final double costPrice;
  final double sellingPrice;
  final String emoji;
}

class _ProductProcurementSheet extends StatefulWidget {
  const _ProductProcurementSheet({required this.item});

  final InventoryItem item;

  @override
  State<_ProductProcurementSheet> createState() => _ProductProcurementSheetState();
}

class _ProductProcurementSheetState extends State<_ProductProcurementSheet> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<_ReceiptAttachment> _attachments = <_ReceiptAttachment>[];

  @override
  void initState() {
    super.initState();
    _costController.text = widget.item.costPrice > 0
        ? widget.item.costPrice.toStringAsFixed(2)
        : widget.item.unitPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(
                controller: _quantityController,
                label: 'Quantity received',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _costController,
                label: 'Cost price per unit',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Supplier invoice or receiving note',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _vendorController, label: 'Supplier name'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: AppTextField(controller: _emailController, label: 'Email')),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _phoneController, label: 'Phone')),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notesController,
                label: 'Receipt notes',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Receipt files', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachments
                    .map(
                      (_ReceiptAttachment attachment) => Chip(
                        avatar: Icon(
                          attachment.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                          size: 18,
                        ),
                        label: Text(attachment.name),
                        onDeleted: () => setState(() => _attachments.remove(attachment)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickReceipts(allowPdf: false),
                      child: const Text('Add image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.secondary(
                      onPressed: () => _pickReceipts(allowPdf: true),
                      child: const Text('Add PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _ProductProcurementDraft(
                        quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
                        costPrice: double.tryParse(_costController.text.trim()) ?? 0,
                        description: _descriptionController.text.trim(),
                        vendorName: _vendorController.text.trim(),
                        vendorEmail: _emailController.text.trim(),
                        vendorPhone: _phoneController.text.trim(),
                        notes: _notesController.text.trim(),
                        attachmentNames: _attachments.map((_ReceiptAttachment attachment) => attachment.name).toList(growable: false),
                        attachmentBase64: _attachments.map((_ReceiptAttachment attachment) => attachment.base64).toList(growable: false),
                        category: TransactionCategory.other,
                      ),
                    );
                  },
                  child: const Text('Save procurement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReceipts({required bool allowPdf}) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowPdf
          ? <String>['jpg', 'jpeg', 'png', 'pdf']
          : <String>['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null) {
      return;
    }
    setState(() {
      for (final PlatformFile file in result.files) {
        final Uint8List? bytes = file.bytes;
        if (bytes == null) {
          continue;
        }
        _attachments.add(
          _ReceiptAttachment(
            name: file.name,
            base64: base64Encode(bytes),
            isPdf: file.extension?.toLowerCase() == 'pdf',
          ),
        );
      }
    });
  }
}

class _ProductProcurementDraft {
  const _ProductProcurementDraft({
    required this.quantity,
    required this.costPrice,
    required this.description,
    required this.vendorName,
    required this.vendorEmail,
    required this.vendorPhone,
    required this.notes,
    required this.attachmentNames,
    required this.attachmentBase64,
    required this.category,
  });

  final double quantity;
  final double costPrice;
  final String description;
  final String vendorName;
  final String vendorEmail;
  final String vendorPhone;
  final String notes;
  final List<String> attachmentNames;
  final List<String> attachmentBase64;
  final TransactionCategory category;
}

class _ReceiptAttachment {
  const _ReceiptAttachment({
    required this.name,
    required this.base64,
    required this.isPdf,
  });

  final String name;
  final String base64;
  final bool isPdf;
}
