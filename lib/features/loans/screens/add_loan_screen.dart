import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/loan.dart';
import '../../../data/models/person.dart';
import '../providers/loans_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/screen_insets.dart';
import '../../../core/theme/tokens.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final String? personId;
  final bool isSettlement;

  const AddLoanScreen({
    super.key,
    this.personId,
    this.isSettlement = false,
  });

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _newPersonController = TextEditingController();

  LoanType _selectedType = LoanType.lent;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPersonId;
  bool _isCreatingNewPerson = false;
  bool _isSaving = false;

  List<Person> _people = [];

  @override
  void initState() {
    super.initState();
    _selectedPersonId = widget.personId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPeople();
    });
  }

  Future<void> _loadPeople() async {
    final repo = ref.read(personRepositoryProvider);
    final people = await repo.getAll();
    if (mounted) {
      setState(() {
        _people = people;
      });

      // Pre-fill settlement amount with outstanding balance
      if (widget.isSettlement && widget.personId != null) {
        final loanRepo = ref.read(loanRepositoryProvider);
        final balance = await loanRepo.getPersonBalance(widget.personId!);
        if (mounted && balance != 0) {
          final absBalance = balance.abs();
          _amountController.text = absBalance == absBalance.roundToDouble()
              ? absBalance.toInt().toString()
              : absBalance.toStringAsFixed(2);
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _newPersonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPersonId == null && !_isCreatingNewPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a person')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(loansProvider.notifier);
      String personId;

      if (_isCreatingNewPerson) {
        final person = await notifier.createPerson(
          name: _newPersonController.text.trim(),
        );
        personId = person.id;
      } else {
        personId = _selectedPersonId!;
      }

      final amount = double.parse(_amountController.text.trim());

      if (widget.isSettlement) {
        await notifier.settleLoan(
          personId: personId,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        await notifier.createLoan(
          personId: personId,
          type: _selectedType,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      }

      if (mounted) {
        await ref.read(dashboardProvider.notifier).refresh();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(widget.isSettlement ? 'Settle Up' : 'Add Loan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: ScreenInsets.of(context, top: Space.lg),
          children: [
            // Person picker
            Text(
              'Person',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (widget.personId != null)
              // Pre-selected person — show as read-only chip
              Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text(
                  _people
                          .where((p) => p.id == widget.personId)
                          .firstOrNull
                          ?.name ??
                      'Loading...',
                ),
              )
            else ...[
              if (!_isCreatingNewPerson) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedPersonId,
                  hint: const Text('Select a person'),
                  items: _people
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPersonId = value);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCreatingNewPerson = true;
                      _selectedPersonId = null;
                    });
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Create New Person'),
                ),
              ] else ...[
                TextFormField(
                  controller: _newPersonController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter person name',
                    prefixIcon: Icon(Icons.person_add),
                  ),
                  validator: (value) {
                    if (_isCreatingNewPerson &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCreatingNewPerson = false;
                      _newPersonController.clear();
                    });
                  },
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('Select Existing Person'),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // Direction (not for settlements)
            if (!widget.isSettlement) ...[
              Text(
                'Direction',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('I Lent'),
                      selected: _selectedType == LoanType.lent,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedType = LoanType.lent);
                        }
                      },
                      selectedColor: context.palette.incomeContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('I Borrowed'),
                      selected: _selectedType == LoanType.borrowed,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedType = LoanType.borrowed);
                        }
                      },
                      selectedColor: context.palette.expenseContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Amount
            Text(
              'Amount ($currency)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid positive amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Date
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat.yMMMd().format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 24),

            // Note
            Text(
              'Note (optional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'e.g., Dinner, Movie tickets...',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isSettlement
                        ? 'Record Settlement'
                        : 'Save Loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
