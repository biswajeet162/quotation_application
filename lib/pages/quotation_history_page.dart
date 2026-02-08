import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/quotation_history.dart';
import '../widgets/page_header.dart';
import 'quotation_preview_page.dart';
import '../utils/google_drive_auth_helper.dart';

class QuotationHistoryPage extends StatefulWidget {
  const QuotationHistoryPage({super.key});

  @override
  State<QuotationHistoryPage> createState() => QuotationHistoryPageState();
}

class QuotationHistoryPageState extends State<QuotationHistoryPage> with AutomaticKeepAliveClientMixin {
  List<QuotationHistory> _quotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _categorizationType = 'all'; // 'all', 'company', 'mobile', 'date', 'creator' // 'email' commented out for now
  DateTime? _lastLoadTime;
  bool _isLoadingInProgress = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  void reloadData() {
    if (mounted && !_isLoadingInProgress) {
      _loadQuotations();
    }
  }

  Future<void> _loadQuotations() async {
    if (!mounted || _isLoadingInProgress) return;
    
    setState(() {
      _isLoading = true;
      _isLoadingInProgress = true;
    });

    try {
      debugPrint('Loading quotations from database...');
      final quotations = await DatabaseHelper.instance.getAllQuotationHistory();
      debugPrint('Loaded ${quotations.length} quotations');
      
      if (mounted) {
        setState(() {
          _quotations = quotations;
          _isLoading = false;
          _isLoadingInProgress = false;
          _lastLoadTime = DateTime.now();
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading quotations: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingInProgress = false;
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

  // Get grouped quotations based on categorization type
  Map<String, List<QuotationHistory>> get _groupedQuotations {
    // First, sort all filtered quotations by date (descending - newest first)
    final filtered = _filteredQuotations;
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    if (_categorizationType == 'all') {
      return {'All Quotations': filtered};
    }

    final grouped = <String, List<QuotationHistory>>{};
    
    for (var quotation in filtered) {
      String key;
      switch (_categorizationType) {
        case 'company':
          key = quotation.customerName.isNotEmpty 
              ? quotation.customerName 
              : 'Unknown Company';
          break;
        // Email categorization commented out for now
        // case 'email':
        //   key = quotation.customerEmail.isNotEmpty 
        //       ? quotation.customerEmail 
        //       : 'No Email';
        //   break;
        case 'mobile':
          key = quotation.customerContact.isNotEmpty 
              ? quotation.customerContact 
              : 'No Mobile';
          break;
        case 'date':
          key = DateFormat('dd-MM-yyyy').format(quotation.createdAt);
          break;
        case 'creator':
          key = quotation.createdBy.isNotEmpty 
              ? quotation.createdBy 
              : 'Unknown';
          break;
        default:
          key = 'All';
      }
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(quotation);
    }

    // Sort groups based on categorization type
    List<String> sortedKeys;
    if (_categorizationType == 'date') {
      // For date, sort by date (newest first)
      sortedKeys = grouped.keys.toList();
      sortedKeys.sort((a, b) {
        try {
          final dateA = DateFormat('dd-MM-yyyy').parse(a);
          final dateB = DateFormat('dd-MM-yyyy').parse(b);
          return dateB.compareTo(dateA); // Descending (newest first)
        } catch (e) {
          return a.compareTo(b); // Fallback to alphabetical if parsing fails
        }
      });
    } else {
      // For other categories, sort alphabetically
      sortedKeys = grouped.keys.toList()..sort();
    }
    
    final sortedGrouped = <String, List<QuotationHistory>>{};
    for (var key in sortedKeys) {
      // Ensure quotations within each group are sorted by date (descending)
      final groupQuotations = grouped[key]!;
      groupQuotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      sortedGrouped[key] = groupQuotations;
    }

    return sortedGrouped;
  }

  Future<void> _deleteQuotation(QuotationHistory quotation) async {
    // Check Google Drive sign-in
    final isSignedIn = await GoogleDriveAuthHelper.checkAndShowNotificationIfNotSignedIn(context);
    if (!isSignedIn) {
      return;
    }

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
        quotationId: quotation.id, // Pass the ID to update action when downloaded
      ),
    ).then((_) {
      // Reload quotations after closing the preview to show updated action
      _loadQuotations();
    });
  }

  Widget _buildGroupedQuotationsList() {
    final grouped = _groupedQuotations;
    
    if (grouped.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, groupIndex) {
        final groupKey = grouped.keys.elementAt(groupIndex);
        final quotations = grouped[groupKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            if (_categorizationType != 'all')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      _categorizationType == 'company'
                          ? Icons.business
                          // : _categorizationType == 'email'
                          //     ? Icons.email
                          : _categorizationType == 'mobile'
                              ? Icons.phone
                              : _categorizationType == 'date'
                                  ? Icons.calendar_today
                                  : Icons.person,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        groupKey,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${quotations.length} quotation${quotations.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Quotations in this group
            ...quotations.map((quotation) => _buildQuotationCard(quotation)),
          ],
        );
      },
    );
  }

  Widget _buildQuotationCard(QuotationHistory quotation) {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Quotation #${quotation.quotationNumber}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: quotation.action == 'download'
                                    ? Colors.blue[100]
                                    // : quotation.action == 'email'
                                    //     ? Colors.orange[100]
                                    : Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    quotation.action == 'download'
                                        ? Icons.download
                                        // : quotation.action == 'email'
                                        //     ? Icons.email
                                        : Icons.save,
                                    size: 14,
                                    color: quotation.action == 'download'
                                        ? Colors.blue[700]
                                        // : quotation.action == 'email'
                                        //     ? Colors.orange[700]
                                        : Colors.green[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    quotation.action == 'download'
                                        ? 'Downloaded'
                                        // : quotation.action == 'email'
                                        //     ? 'Emailed'
                                        : 'Saved',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: quotation.action == 'download'
                                          ? Colors.blue[700]
                                          // : quotation.action == 'email'
                                          //     ? Colors.orange[700]
                                          : Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Show company name only if not categorizing by company
                        if (_categorizationType != 'company')
                          Text(
                            quotation.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Email display commented out for now
                        // Show email only if not categorizing by email
                        // if (_categorizationType != 'email' &&
                        //     quotation.customerEmail.isNotEmpty)
                        //   Text(
                        //     quotation.customerEmail,
                        //     style: TextStyle(
                        //       fontSize: 14,
                        //       color: Colors.grey[600],
                        //     ),
                        //   ),
                        // Show mobile only if not categorizing by mobile
                        if (_categorizationType != 'mobile' &&
                            quotation.customerContact.isNotEmpty)
                          Text(
                            quotation.customerContact,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        // Show date only if not categorizing by date
                        if (_categorizationType == 'date')
                          Text(
                            'Company: ${quotation.customerName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${quotation.items.length} item(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        // Show creator only if not categorizing by creator
                        if (_categorizationType != 'creator') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Created by: ${quotation.createdBy}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _deleteQuotation(quotation),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
                // Categorization dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: DropdownButton<String>(
                    value: _categorizationType,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'company', child: Text('By Company')),
                      // DropdownMenuItem(value: 'email', child: Text('By Email')), // Email feature commented out for now
                      DropdownMenuItem(value: 'mobile', child: Text('By Mobile Number')),
                      DropdownMenuItem(value: 'date', child: Text('By Date')),
                      DropdownMenuItem(value: 'creator', child: Text('By Creator')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _categorizationType = value!;
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
                              _searchQuery.isNotEmpty
                                  ? 'No quotations found matching your criteria'
                                  : 'No quotation history yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Download a quotation to see it here', // Email feature commented out
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : _buildGroupedQuotationsList(),
          ),
        ],
      ),
    );
  }
}

