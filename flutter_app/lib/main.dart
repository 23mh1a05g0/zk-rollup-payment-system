import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZK Rollup Payment System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07070C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          primary: Colors.deepPurpleAccent,
          secondary: Colors.tealAccent,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF12121E),
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F0F1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardScreen(),
        '/send': (context) => const SendScreen(),
        '/history': (context) => const HistoryScreen(),
        '/batches': (context) => const BatchesScreen(),
      },
    );
  }
}

// Custom layout container to avoid code duplication
class WalletLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const WalletLayout({super.key, required this.child, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF08080F),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "ZK-Rollup Wallet",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Layer 2 Scaling Simulation",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Colors.deepPurpleAccent),
                title: const Text("Dashboard"),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.blueAccent),
                title: const Text("Send Payment"),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/send');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.amberAccent),
                title: const Text("Transaction History"),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/history');
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers, color: Colors.greenAccent),
                title: const Text("Batch Explorer"),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/batches');
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06060B), Color(0xFF0C0C15)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// Helper to truncate addresses
String truncateAddress(String address) {
  if (address.length <= 12) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

// ---------------- 1. DASHBOARD SCREEN ----------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _addressController = TextEditingController();

  bool _loadingState = false;
  bool _loadingBalance = false;
  String _errorMsg = '';

  Map<String, dynamic>? _stateData;
  Map<String, dynamic>? _balanceData;

  @override
  void initState() {
    super.initState();
    _loadState();
    // Default to user address if pre-filled
    _addressController.text = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; // Account #0 default
    _loadBalance();
  }

  Future<void> _loadState() async {
    setState(() {
      _loadingState = true;
      _errorMsg = '';
    });
    try {
      final data = await _api.getRollupState();
      setState(() {
        _stateData = data;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to fetch contract state: $e';
      });
    } finally {
      setState(() {
        _loadingState = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) return;
    setState(() {
      _loadingBalance = true;
    });
    try {
      final data = await _api.getDeposit(addr);
      setState(() {
        _balanceData = data;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to fetch deposit balance: $e';
      });
    } finally {
      setState(() {
        _loadingBalance = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await _loadState();
    await _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    return WalletLayout(
      title: "Dashboard",
      child: ListView(
        children: [
          // On-Chain Address Input Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Select Wallet Address",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: "Wallet Address",
                      hintText: "wallet address",
                    ),
                    onChanged: (val) {
                      _loadBalance();
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loadingState || _loadingBalance
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Refresh", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMsg, style: const TextStyle(color: Colors.redAccent)),
            ),

          // User Balance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ON-CHAIN DEPOSIT BALANCE", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  _loadingBalance
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_balanceData?['balanceEth'] ?? '0.0'} ETH",
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_balanceData?['balanceWei'] ?? '0'} Wei",
                              style: const TextStyle(fontSize: 14, color: Colors.white38),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),

          // Rollup State Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ROLLUP GLOBAL STATE", style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  _loadingState
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            _buildStateRow("State Root", truncateAddress(_stateData?['currentStateRoot'] ?? '0x0000000000000000000000000000000000000000000000000000000000000000')),
                            _buildStateRow("Batch Count", (_stateData?['batchCount'] ?? 0).toString()),
                            _buildStateRow("Contract Address", truncateAddress(_stateData?['contractAddress'] ?? 'N/A')),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

// ---------------- 2. SEND SCREEN ----------------
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _submitting = false;
  String _statusMsg = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _fromController.text = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  }

  // Convert ETH input to Wei
  String ethToWei(String ethStr) {
    try {
      double eth = double.parse(ethStr);
      BigInt wei = BigInt.from((eth * 1e9).round()) * BigInt.from(1e9);
      return wei.toString();
    } catch (_) {
      return ethStr;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _statusMsg = '';
      _isSuccess = false;
    });

    final fromVal = _fromController.text.trim();
    final toVal = _toController.text.trim();
    final amountEthVal = _amountController.text.trim();
    final amountWei = ethToWei(amountEthVal);

    try {
      final res = await _api.submitIntent(fromVal, toVal, amountWei);
      if (res.containsKey('error')) {
        setState(() {
          _isSuccess = false;
          _statusMsg = 'Error: ${res['error']}';
        });
      } else {
        setState(() {
          _isSuccess = true;
          _statusMsg = 'Intent submitted successfully! ID: ${res['intentId']}';
          _toController.clear();
          _amountController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMsg = 'Failed to submit intent: $e';
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WalletLayout(
      title: "Send Payment",
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  "Create Rollup Transaction Intent",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fromController,
                  decoration: const InputDecoration(
                    labelText: "From Address",
                    hintText: "from address",
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _toController,
                  decoration: const InputDecoration(
                    labelText: "To Address",
                    hintText: "to address",
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: "Amount (ETH)",
                    hintText: "amount",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit Intent", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (_statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    _statusMsg,
                    style: TextStyle(
                      color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 3. HISTORY SCREEN ----------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _filterController = TextEditingController();

  List<dynamic> _intents = [];
  bool _loading = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    try {
      final address = _filterController.text.trim();
      final data = await _api.getIntents(address: address.isNotEmpty ? address : null);
      setState(() {
        _intents = data;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to load transaction history: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amberAccent;
      case 'batched':
        return Colors.blueAccent;
      case 'committed':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WalletLayout(
      title: "Transaction History",
      child: Column(
        children: [
          // Filter card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filterController,
                      decoration: const InputDecoration(
                        labelText: "Filter by address",
                        hintText: "filter",
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) {
                        _fetchHistory();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                    onPressed: _fetchHistory,
                  ),
                ],
              ),
            ),
          ),

          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMsg, style: const TextStyle(color: Colors.redAccent)),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _intents.isEmpty
                    ? const Center(child: Text("No intents found for this address"))
                    : ListView.builder(
                        itemCount: _intents.length,
                        itemBuilder: (context, index) {
                          final item = _intents[index];
                          final status = item['status'] as String;
                          final from = item['from_address'] as String;
                          final to = item['to_address'] as String;
                          final amount = item['amount_wei'] as String;
                          final id = item['id'] as String;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                child: Icon(
                                  status.toLowerCase() == 'failed' ? Icons.error : Icons.send,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              title: Text(
                                "$amount Wei",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text("From: ${truncateAddress(from)}"),
                                  Text("To: ${truncateAddress(to)}"),
                                  const SizedBox(height: 2),
                                  Text("ID: ${truncateAddress(id)}", style: const TextStyle(fontSize: 11, color: Colors.white30)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
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

// ---------------- 4. BATCH EXPLORER SCREEN ----------------
class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final ApiService _api = ApiService();

  List<dynamic> _batches = [];
  bool _loadingList = false;
  String _errorMsg = '';

  // Detail view state
  Map<String, dynamic>? _selectedBatchDetail;
  List<dynamic> _associatedIntents = [];
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    setState(() {
      _loadingList = true;
      _errorMsg = '';
    });
    try {
      final data = await _api.getBatches();
      setState(() {
        _batches = data;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to load batches: $e';
      });
    } finally {
      setState(() {
        _loadingList = false;
      });
    }
  }

  Future<void> _selectBatch(int batchIndex) async {
    setState(() {
      _loadingDetail = true;
      _selectedBatchDetail = null;
      _associatedIntents = [];
    });
    try {
      final data = await _api.getBatchDetail(batchIndex);
      setState(() {
        _selectedBatchDetail = data['batch'] as Map<String, dynamic>;
        _associatedIntents = data['intents'] as List<dynamic>;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load batch detail: $e')),
      );
    } finally {
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If a batch is selected, show details
    if (_selectedBatchDetail != null || _loadingDetail) {
      return WalletLayout(
        title: "Batch #${_selectedBatchDetail?['batch_index'] ?? ''} Details",
        child: _loadingDetail
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _selectedBatchDetail = null;
                            _associatedIntents = [];
                          });
                        },
                      ),
                      const Text("Back to Batch List", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow("Batch Index", _selectedBatchDetail?['batch_index']?.toString() ?? ''),
                          _buildDetailRow("Transaction Count", _selectedBatchDetail?['tx_count']?.toString() ?? '0'),
                          _buildDetailRow("State Root Update", 
                            "${truncateAddress(_selectedBatchDetail?['old_state_root'] ?? '0x00...')} ➔ ${truncateAddress(_selectedBatchDetail?['new_state_root'] ?? '')}"),
                          _buildDetailRow("Batch Hash", truncateAddress(_selectedBatchDetail?['batch_hash'] ?? '')),
                          _buildDetailRow("Relayer", truncateAddress(_selectedBatchDetail?['relayer_address'] ?? '')),
                          _buildDetailRow("TX Hash", truncateAddress(_selectedBatchDetail?['tx_hash'] ?? '')),
                          _buildDetailRow("Committed At", _selectedBatchDetail?['committed_at']?.toString() ?? 'Pending'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Associated Payment Intents",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _associatedIntents.isEmpty
                        ? const Center(child: Text("No intents associated with this batch"))
                        : ListView.builder(
                            itemCount: _associatedIntents.length,
                            itemBuilder: (context, index) {
                              final item = _associatedIntents[index];
                              return Card(
                                child: ListTile(
                                  title: Text("${item['amount_wei']} Wei", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("From: ${truncateAddress(item['from_address'])} ➔ To: ${truncateAddress(item['to_address'])}"),
                                  trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      );
    }

    return WalletLayout(
      title: "Batch Explorer",
      child: Column(
        children: [
          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMsg, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _batches.isEmpty
                    ? const Center(child: Text("No committed batches found"))
                    : ListView.builder(
                        itemCount: _batches.length,
                        itemBuilder: (context, index) {
                          final batch = _batches[index];
                          final batchIdx = batch['batch_index'] as int;
                          final txCount = batch['tx_count'] as int;
                          final newStateRoot = batch['new_state_root'] as String;
                          final committedAt = batch['committed_at'] as String?;

                          return Card(
                            child: InkWell(
                              onTap: () => _selectBatch(batchIdx),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.deepPurpleAccent.withOpacity(0.15),
                                      child: const Icon(Icons.layers, color: Colors.deepPurpleAccent),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Batch #$batchIdx",
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "State Root: ${truncateAddress(newStateRoot)}",
                                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                                          ),
                                          if (committedAt != null)
                                            Text(
                                              "Committed: ${committedAt.substring(0, 10)} ${committedAt.substring(11, 19)}",
                                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "$txCount txs",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent),
                                        ),
                                        const SizedBox(height: 4),
                                        const Row(
                                          children: [
                                            Text("View Details", style: TextStyle(fontSize: 12, color: Colors.deepPurpleAccent)),
                                            Icon(Icons.chevron_right, size: 16, color: Colors.deepPurpleAccent),
                                          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}