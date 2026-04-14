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
      debugShowCheckedModeBanner: false,
      home: WalletScreen(),
    );
  }
}

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List intents = [];
  int? lastBatchId;
  String txHash = "";
  bool isLoading = false;

  final fromController = TextEditingController();
  final toController = TextEditingController();
  final amountController = TextEditingController();

  // Load intents
  void loadIntents() async {
    try {
      final data = await ApiService.getIntents();
      setState(() {
        intents = data;
      });
    } catch (e) {
      showMsg("Failed to load intents ❌");
    }
  }

  @override
  void initState() {
    super.initState();
    loadIntents();
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // CREATE INTENT
  Future<void> sendPayment() async {
    if (fromController.text.isEmpty ||
        toController.text.isEmpty ||
        amountController.text.isEmpty) {
      showMsg("Fill all fields ❗");
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService.createIntent(
        fromController.text,
        toController.text,
        amountController.text,
      );

      showMsg("Payment Intent Created ✅");
      loadIntents();
    } catch (e) {
      showMsg("Error creating payment ❌");
    }

    setState(() => isLoading = false);
  }

  // CREATE BATCH
  Future<void> createBatch() async {
    setState(() => isLoading = true);

    try {
      final res = await ApiService.createBatch();

      if (res["batch"] != null) {
        setState(() {
          lastBatchId = res["batch"]["id"];
        });
        showMsg("Batch Created ✅");
      } else {
        showMsg(res["message"] ?? "No pending transactions");
      }
    } catch (e) {
      showMsg("Batch creation failed ❌");
    }

    setState(() => isLoading = false);
  }

  // COMMIT BATCH
  Future<void> commitBatch() async {
    if (lastBatchId == null) return;

    setState(() => isLoading = true);

    try {
      final res = await ApiService.commitBatch(lastBatchId!);

      print(res); // debug

      if (res["txHash"] != null) {
        setState(() {
          txHash = res["txHash"];
        });
        showMsg("Batch Committed 🚀");
      } else {
        showMsg(res["error"] ?? "Commit failed ❌");
      }
    } catch (e) {
      showMsg("Blockchain error ❌");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ZK Wallet 🚀"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // INPUTS
            TextField(
              controller: fromController,
              decoration: const InputDecoration(labelText: "From Address"),
            ),
            TextField(
              controller: toController,
              decoration: const InputDecoration(labelText: "To Address"),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: "Amount (wei)"),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 10),

            // SEND PAYMENT
            ElevatedButton(
              onPressed: sendPayment,
              child: const Text("Send Payment"),
            ),

            // CREATE BATCH
            ElevatedButton(
              onPressed: createBatch,
              child: const Text("Create Batch"),
            ),

            // COMMIT BATCH
            ElevatedButton(
              onPressed: lastBatchId == null ? null : commitBatch,
              child: const Text("Commit Batch"),
            ),

            const SizedBox(height: 10),

            // LOADING
            if (isLoading) const CircularProgressIndicator(),

            // BATCH INFO
            if (lastBatchId != null)
              Text(
                "Batch ID: $lastBatchId",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

            // TX HASH
            if (txHash.isNotEmpty)
              SelectableText(
                "TxHash:\n$txHash",
                style: const TextStyle(color: Colors.green),
              ),

            const Divider(),

            // TRANSACTION LIST
            Expanded(
              child: intents.isEmpty
                  ? const Center(child: Text("No Transactions"))
                  : ListView.builder(
                      itemCount: intents.length,
                      itemBuilder: (context, index) {
                        final item = intents[index];

                        return Card(
                          elevation: 3,
                          child: ListTile(
                            title: Text("Amount: ${item['amount_wei']}"),
                            subtitle: Text(
                              "${item['from_address']} → ${item['to_address']}",
                            ),
                            trailing: Text(
                              item['status'],
                              style: TextStyle(
                                color: item['status'] == "pending"
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}