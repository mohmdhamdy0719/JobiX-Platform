import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import 'authenticated_navigation.dart';
import 'core_api.dart';

class CreditsPage extends ConsumerStatefulWidget {
  const CreditsPage({super.key});

  @override
  ConsumerState<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends ConsumerState<CreditsPage> {
  final List<Map<String, dynamic>> _items = [];
  String? _nextCursor;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasLoaded = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authSessionProvider.select((state) => state.valueOrNull?.user.id),
      (previous, next) {
        if (previous != next) _loadFirstPage();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _nextCursor = null;
      _hasLoaded = false;
    });
    try {
      final api = await ref.read(coreApiProvider.future);
      final page = await api.transactions();
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final api = await ref.read(coreApiProvider.future);
      final page = await api.transactions(cursor: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SliceScaffold(
      title: copy.creditHistoryTitle,
      leading: const BrandMark(size: 32),
      bottom: const AuthenticatedNavigation(selected: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: copy.creditHistoryTitle,
            subtitle: copy.creditHistorySubtitle,
          ),
          const SizedBox(height: TokensV0.space20),
          ref
              .watch(coreSummaryProvider)
              .when(
                loading: () => const _BalanceState(loading: true),
                error: (_, __) => SliceCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(copy.balanceUnavailable)),
                      IconButton(
                        tooltip: copy.retry,
                        onPressed: () => ref.invalidate(coreSummaryProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                data: (summary) => SliceCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: TokensV0.deepBlue,
                      ),
                      const SizedBox(width: TokensV0.space12),
                      Expanded(child: Text(copy.availableCredits)),
                      Text(
                        '${summary.balance.available}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: TokensV0.space20),
          if (_loading)
            const _HistoryLoading()
          else if (!_hasLoaded || _error != null && _items.isEmpty)
            SliceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.creditHistoryLoadFailed),
                  const SizedBox(height: TokensV0.space8),
                  TextButton.icon(
                    onPressed: _loadFirstPage,
                    icon: const Icon(Icons.refresh),
                    label: Text(copy.retry),
                  ),
                ],
              ),
            )
          else if (_items.isEmpty)
            SliceCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: TokensV0.textSecondary,
                  ),
                  const SizedBox(height: TokensV0.space12),
                  Text(
                    copy.creditHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            )
          else ...[
            for (var index = 0; index < _items.length; index++) ...[
              if (index > 0) const SizedBox(height: TokensV0.space8),
              _TransactionCard(item: _items[index], locale: locale, copy: copy),
            ],
            if (_error != null) ...[
              const SizedBox(height: TokensV0.space12),
              SliceCard(
                child: Row(
                  children: [
                    Expanded(child: Text(copy.moreTransactionsFailed)),
                    TextButton(onPressed: _loadMore, child: Text(copy.retry)),
                  ],
                ),
              ),
            ],
            if (_nextCursor != null) ...[
              const SizedBox(height: TokensV0.space12),
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: _loadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(copy.loadMore),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BalanceState extends StatelessWidget {
  const _BalanceState({required this.loading});
  final bool loading;
  @override
  Widget build(BuildContext context) => SliceCard(
    child: Row(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: TokensV0.surfaceContainer,
            borderRadius: BorderRadius.all(
              Radius.circular(TokensV0.controlRadius),
            ),
          ),
          child: SizedBox(width: 40, height: 40),
        ),
        const SizedBox(width: TokensV0.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: loading ? 130 : 90, height: 14),
              ),
              const SizedBox(height: TokensV0.space8),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: 56, height: 18),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < 3; index++) ...[
        if (index > 0) const SizedBox(height: TokensV0.space8),
        const SliceCard(
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.controlRadius),
                  ),
                ),
                child: SizedBox(width: 36, height: 36),
              ),
              SizedBox(width: TokensV0.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: TokensV0.surfaceContainer,
                        borderRadius: BorderRadius.all(
                          Radius.circular(TokensV0.chipRadius),
                        ),
                      ),
                      child: SizedBox(width: 144, height: 14),
                    ),
                    SizedBox(height: TokensV0.space8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: TokensV0.surfaceContainer,
                        borderRadius: BorderRadius.all(
                          Radius.circular(TokensV0.chipRadius),
                        ),
                      ),
                      child: SizedBox(width: 96, height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.item,
    required this.locale,
    required this.copy,
  });
  final Map<String, dynamic> item;
  final String locale;
  final AppLocalizations copy;

  @override
  Widget build(BuildContext context) {
    final deltaValue = item['delta'];
    final delta = deltaValue is num ? deltaValue.toInt() : null;
    final rawType = item['reference_type']?.toString() ?? '';
    final type = rawType.replaceAll('_', ' ').trim();
    final rawDate = item['created_at']?.toString();
    final date = rawDate == null ? null : DateTime.tryParse(rawDate)?.toLocal();
    return SliceCard(
      padding: const EdgeInsetsDirectional.all(TokensV0.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            delta == null
                ? Icons.receipt_long_outlined
                : delta >= 0
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            color: delta == null
                ? TokensV0.textSecondary
                : delta >= 0
                ? TokensV0.success
                : TokensV0.textSecondary,
          ),
          const SizedBox(width: TokensV0.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.isEmpty ? copy.creditTransaction : type,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                if (date != null)
                  Text(
                    DateFormat.yMMMd(locale).add_jm().format(date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: TokensV0.space8),
          Text(
            delta == null ? '—' : '${delta > 0 ? '+' : ''}$delta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: delta == null
                  ? TokensV0.textSecondary
                  : delta >= 0
                  ? TokensV0.success
                  : TokensV0.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
