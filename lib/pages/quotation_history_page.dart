import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/quotation_history.dart';
import '../widgets/page_header.dart';
import 'quotation_preview_page.dart';

class QuotationHistoryPage extends StatefulWidget {
  const QuotationHistoryPage({super.key});

  @override
  State<QuotationHistoryPage> createState() => _QuotationHistoryPageState();
}

class _QuotationHistoryPageState extends State<QuotationHistoryPage> {
  List<QuotationHistory> _quotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterAction = 'all'; // 'all', 'download', 'email'

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Loading quotations from database...');
      final quotations = await DatabaseHelper.instance.getAllQuotationHistory();
      debugPrint('Loaded ${quotations.length} quotations');
      
      if (mounted) {
        setState(() {
          _quotations = quotations;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading quotations: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _quotations = []; // Ensure list is empty on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quotations: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadQuotations,
            ),
          ),
        );
      }
    }
  }

  List<QuotationHistory> get _filteredQuotations {
    var filtered = _quotations;

    // Filter by action type
    if (_filterAction != 'all') {
      filtered = filtered.where((q) => q.action == _filterAction).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((q) {
        return q.quotationNumber.toLowerCase().contains(query) ||
            q.customerName.toLowerCase().contains(query) ||
            q.customerEmail.toLowerCase().contains(query) ||
            q.customerContact.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _deleteQuotation(QuotationHistory quotation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text(
          'Are you sure you want to delete quotation #${quotation.quotationNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteQuotationHistory(quotation.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quotation deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadQuotations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting quotation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewQuotationDetails(QuotationHistory quotation) {
    showDialog(
      context: context,
      builder: (context) => QuotationPreviewPage(
        quotationNumber: quotation.quotationNumber,
        quotationDate: quotation.quotationDate,
        customerName: quotation.customerName,
        customerAddress: quotation.customerAddress,
        customerContact: quotation.customerContact,
        customerEmail: quotation.customerEmail,
        items: quotation.items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          PageHeader(
            title: 'Quotation History',
            count: _filteredQuotations.length,
          ),
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by quotation number, customer name, email, or contact...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButton<String>(
                    value: _filterAction,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Actions')),
                      DropdownMenuItem(value: 'download', child: Text('Downloaded')),
                      DropdownMenuItem(value: 'email', child: Text('Emailed')),
                      DropdownMenuItem(value: 'saved', child: Text('Saved')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterAction = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _loadQuotations,
                ),
              ],
            ),
          ),
          // Quotations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredQuotations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _filterAction != 'all'
                                  ? 'No quotations found matching your criteria'
                                  : 'No quotation history yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isEmpty && _filterAction == 'all')
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Download or email a quotation to see it here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredQuotations.length,
                        itemBuilder: (context, index) {
                          final quotation = _filteredQuotations[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _viewQuotationDetails(quotation),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Quotation #${quotation.quotationNumber}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: quotation.action ==
                                                              'download'
                                                          ? Colors.blue[100]
                                                          : quotation.action ==
                                                                  'email'
                                                              ? Colors.orange[100]
                                                              : Colors.green[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          quotation.action ==
                                                                  'download'
                                                              ? Icons.download
                                                              : quotation.action ==
                                                                      'email'
                                                                  ? Icons.email
                                                                  : Icons.save,
                                                          size: 14,
                                                          color: quotation
                                                                      .action ==
                                                                  'download'
                                                              ? Colors.blue[700]
                                                              : quotation
                                                                          .action ==
                                                                      'email'
                                                                  ? Colors
                                                                      .orange[700]
                                                                  : Colors
                                                                      .green[700],
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          quotation.action ==
                                                                  'download'
                                                              ? 'Downloaded'
                                                              : quotation.action ==
                                                                      'email'
                                                                  ? 'Emailed'
                                                                  : 'Saved',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: quotation
                                                                        .action ==
                                                                    'download'
                                                                ? Colors
                                                                    .blue[700]
                                                                : quotation
                                                                            .action ==
                                                                        'email'
                                                                    ? Colors
                                                                        .orange[700]
                                                                    : Colors
                                                                        .green[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                quotation.customerName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (quotation.customerEmail
                                                  .isNotEmpty)
                                                Text(
                                                  quotation.customerEmail,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${quotation.grandTotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('dd-MM-yyyy')
                                                  .format(quotation.quotationDate),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${quotation.items.length} item(s)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd-MM-yyyy HH:mm')
                                              .format(quotation.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () =>
                                              _deleteQuotation(quotation),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

