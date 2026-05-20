/// HandTalk - History/Riwayat Page
/// Pattern: StatefulWidget + setState(), imperative navigation, SnackBar feedback
/// Menampilkan riwayat terjemahan user dengan statistik, swipe-to-delete, detail bottom sheet

import 'package:flutter/material.dart';

import 'core/themes.dart';
import 'services/auth_service.dart';
import 'services/history_service.dart';

class HistoryPage extends StatefulWidget {
  final UserModel user;

  const HistoryPage({super.key, required this.user});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // ─── State Variables ──────────────────────────────────────────────────────
  bool _isLoading = true;
  List<HistoryModel> _historyList = [];
  int _totalCount = 0;
  int _sessionCount = 0;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final historyService = HistoryService();
      final userId = widget.user.id ?? 0;

      final history = await historyService.getHistoryByUserId(userId);
      final totalCount = await historyService.getHistoryCount(userId);
      final sessionCount = await historyService.getSessionCount(userId);

      if (!mounted) return;

      setState(() {
        _historyList = history;
        _totalCount = totalCount;
        _sessionCount = sessionCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Gagal memuat riwayat', isError: true);
    }
  }

  // ─── Delete Single Item ───────────────────────────────────────────────────

  Future<void> _deleteHistoryItem(HistoryModel item, int index) async {
    try {
      final historyService = HistoryService();
      await historyService.deleteHistory(item.id ?? 0);

      if (!mounted) return;

      setState(() {
        _historyList.removeAt(index);
        _totalCount = _historyList.length;
      });

      _showSnackBar('Riwayat berhasil dihapus', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal menghapus riwayat', isError: true);
      // Reload to restore state
      _loadHistory();
    }
  }

  // ─── Clear All History ────────────────────────────────────────────────────

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Riwayat'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua riwayat terjemahan? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final historyService = HistoryService();
      await historyService.clearUserHistory(widget.user.id ?? 0);

      if (!mounted) return;

      setState(() {
        _historyList.clear();
        _totalCount = 0;
        _sessionCount = 0;
      });

      _showSnackBar('Semua riwayat berhasil dihapus', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal menghapus riwayat', isError: true);
    }
  }

  // ─── Show Detail Bottom Sheet ─────────────────────────────────────────────

  void _showDetailBottomSheet(HistoryModel item) {
    final direction = item.translationDirection ?? 'unknown';
    final directionLabel = direction == 'text_to_sign'
        ? 'Teks → Isyarat'
        : direction == 'sign_to_text'
            ? 'Isyarat → Teks'
            : 'Tidak diketahui';
    final timeStr = _formatDateTime(item.createdAt);
    final confidence = (item.confidenceScore * 100).toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Detail Terjemahan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Direction
              _buildDetailRow(
                icon: Icons.swap_horiz,
                label: 'Arah',
                value: directionLabel,
              ),
              const SizedBox(height: 12),
              // Source text
              _buildDetailRow(
                icon: Icons.text_fields,
                label: 'Teks Sumber',
                value: item.sourceText ?? item.inputData ?? '-',
              ),
              const SizedBox(height: 12),
              // Translated text
              _buildDetailRow(
                icon: Icons.translate,
                label: 'Hasil Terjemahan',
                value: item.translatedText ?? '-',
              ),
              const SizedBox(height: 12),
              // Confidence
              _buildDetailRow(
                icon: Icons.speed,
                label: 'Confidence',
                value: '$confidence%',
              ),
              const SizedBox(height: 12),
              // Processing time
              if (item.processingTimeMs != null)
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Waktu Proses',
                  value: '${item.processingTimeMs} ms',
                ),
              if (item.processingTimeMs != null) const SizedBox(height: 12),
              // Time
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'Waktu',
                value: timeStr,
              ),
              const SizedBox(height: 12),
              // Session ID
              if (item.sessionId != null)
                _buildDetailRow(
                  icon: Icons.fingerprint,
                  label: 'Sesi',
                  value: item.sessionId!.length > 8
                      ? '${item.sessionId!.substring(0, 8)}...'
                      : item.sessionId!,
                ),
              const SizedBox(height: 20),
              // Close button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── SnackBar Helper ──────────────────────────────────────────────────────

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Terjemahan'),
        actions: [
          if (_historyList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Hapus Semua',
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppColors.primary,
        child: _isLoading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_historyList.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStatsHeader(),
        Expanded(
          child: _buildHistoryList(),
        ),
      ],
    );
  }

  // ─── Stats Header ────────────────────────────────────────────────────────

  Widget _buildStatsHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatColumn(
              icon: Icons.list_alt,
              value: '$_totalCount',
              label: 'Total Log',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.primary.withOpacity(0.2),
          ),
          Expanded(
            child: _buildStatColumn(
              icon: Icons.layers_outlined,
              value: '$_sessionCount',
              label: 'Sesi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── History List ─────────────────────────────────────────────────────────

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _historyList.length,
      itemBuilder: (context, index) {
        final item = _historyList[index];
        return _buildHistoryItem(item, index);
      },
    );
  }

  Widget _buildHistoryItem(HistoryModel item, int index) {
    final direction = item.translationDirection ?? 'unknown';
    final isTextToSign = direction == 'text_to_sign';
    final directionIcon =
        isTextToSign ? Icons.text_fields : Icons.sign_language;
    final directionColor = isTextToSign ? AppColors.info : AppColors.secondary;
    final directionLabel = isTextToSign ? 'T→I' : 'I→T';
    final sourceText = item.sourceText ?? item.inputData ?? '-';
    final translatedText = item.translatedText ?? '-';
    final timeStr = _formatTime(item.createdAt);

    return Dismissible(
      key: Key('history_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Riwayat'),
            content:
                const Text('Apakah Anda yakin ingin menghapus riwayat ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteHistoryItem(item, index),
      child: GestureDetector(
        onTap: () => _showDetailBottomSheet(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Direction icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: directionColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(directionIcon, color: directionColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      translatedText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time and badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: directionColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      directionLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: directionColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return ListView(
      // ListView agar pull-to-refresh tetap berfungsi
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 72,
                  color: AppColors.textHint.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Riwayat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Riwayat terjemahan Anda akan\nmuncul di sini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Detail Row Helper ────────────────────────────────────────────────────

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Time Formatting Helpers ──────────────────────────────────────────────

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}
