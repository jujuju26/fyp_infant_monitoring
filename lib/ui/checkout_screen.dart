import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'payment_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedPackages;

  const CheckoutScreen({Key? key, required this.selectedPackages})
      : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // This date now means: due date OR birth/check-in date depending on toggle
  DateTime _selectedDate = DateTime.now();

  // baby condition + stay length
  bool _isBabyBorn = false; // false = baby not born yet (use due date)
  int _stayLengthDays = 28; // 28 days (1 month) or 56 days (2 months)
  int _selectedMonths = 1; // default 1 month

  String _paymentMethod = 'card';
  bool _isLoading = false;

  String _formatDate(DateTime d) => DateFormat('d MMMM yyyy').format(d);
  String _formatCurrency(double amount) => 'RM ${amount.toStringAsFixed(2)}';

  // (not used anymore but kept if you want true month-based later)
  DateTime _addMonths(DateTime src, int monthsToAdd) {
    int newYear = src.year + ((src.month - 1 + monthsToAdd) ~/ 12);
    int newMonth = ((src.month - 1 + monthsToAdd) % 12) + 1;

    // Get last valid day of the target month
    int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;

    // Use min(day, last day of new month)
    int newDay = src.day <= lastDayOfNewMonth ? src.day : lastDayOfNewMonth;

    return DateTime(
      newYear,
      newMonth,
      newDay,
      src.hour,
      src.minute,
      src.second,
    );
  }

  DateTime get _checkInDate => _selectedDate;
  DateTime get _checkOutDate =>
      _checkInDate.add(Duration(days: _stayLengthDays));

  double get _totalPayable {
    double sum = 0.0;

    for (final pkg in widget.selectedPackages) {
      final price = (pkg['price'] ?? 0).toDouble();
      final quantity = pkg['quantity'] ?? 1;

      // base = 1 month; 2 months = +50%
      double finalPrice = price;
      if (_selectedMonths == 2) {
        finalPrice = price + (price * 0.5);
      }

      sum += finalPrice * quantity;
    }

    return sum;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    // Option A behaviour:
    // - If baby NOT born → EDD must be today or future (no past dates)
    // - If baby already born → allow up to 30 days in the past
    final firstDate =
    _isBabyBorn ? now.subtract(const Duration(days: 30)) : now;

    final initial =
    _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 3),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveBookingToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final bookingData = {
        'packages': widget.selectedPackages,

        // logic fields
        'isBabyBorn': _isBabyBorn,
        'stayLengthDays': _stayLengthDays,
        'stayLengthMonths': _selectedMonths,
        'baseDate': _selectedDate.toIso8601String(), // EDD or check-in/birth

        // keep old fields so other screens continue to work
        'checkInDate': _checkInDate.toIso8601String(),
        'checkOutDate': _checkOutDate.toIso8601String(),

        'paymentMethod': _paymentMethod,
        'totalPayable': _totalPayable,
        'status': 'PENDING',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('parent')
          .doc(user.uid)
          .collection('bookings')
          .add(bookingData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking saved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save booking: $e')),
      );
      rethrow;
    }
  }

  Future<void> _onCheckoutPressed() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _saveBookingToFirebase();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessScreen()),
      );
    } catch (_) {
      // already handled snackbar in _saveBookingToFirebase
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------- UI HELPERS ----------------

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final String name = pkg['name'] ?? 'Package Name';
    final String location =
        pkg['location'] ?? 'No. 45, Jalan Ampang, 50450 Kuala Lumpur';
    final double price = (pkg['price'] ?? 0).toDouble();
    final int quantity = pkg['quantity'] ?? 1;

    // Use the computed check-in / check-out based on current selection
    final DateTime checkOutDate = _checkOutDate;

    // NEW PRICE LOGIC:
    // 1 month  = base price
    // 2 months = +50% on base
    double finalPrice = price;
    if (_selectedMonths == 2) {
      finalPrice = price + (price * 0.5); // 50% extra for month 2
    }
    double subtotal = finalPrice * quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFADADD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFFC2868B),
            ),
          ),
          const SizedBox(height: 8),

          // Location Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined,
                  size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price row (always show base price per month)
          Row(
            children: [
              const Icon(Icons.attach_money,
                  size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Price per month: RM ${price.toStringAsFixed(2)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Show long-stay note ONLY when 2 months selected
          if (_selectedMonths == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "+ 50% long-stay charge applied (2nd month)",
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),

          // Check-in
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Check-in: ${_formatDate(_checkInDate)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Check-out
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Check-out: ${_formatDate(checkOutDate)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quantity
          Row(
            children: [
              const Icon(Icons.production_quantity_limits,
                  size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Text(
                'Quantity: $quantity',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Subtotal
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB77E84),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Subtotal: RM ${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfinementPeriodSelector() {
    final List<Map<String, dynamic>> periods = [
      {"label": "1 month (28 days)", "months": 1, "days": 28},
      {"label": "2 months (56 days)", "months": 2, "days": 56},
    ];

    return SizedBox(
      height: 55,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final p = periods[index];
          final bool selected = _selectedMonths == p["months"];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFADADD) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                selected ? const Color(0xFFC2868B) : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: const Color(0xFFC2868B).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
                  : [],
            ),
            child: Center(
              child: Text(
                p["label"] as String,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color:
                  selected ? const Color(0xFFC2868B) : Colors.black87,
                  fontSize: 13.5,
                ),
              ),
            ),
          ).rippleTap(() {
            setState(() {
              _selectedMonths = p["months"] as int;
              _stayLengthDays = p["days"] as int;
            });
          });
        },
      ),
    );
  }

  Widget _buildBabyStatusToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Text(
                'Baby not born yet\n(Use due date)',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
              ),
              selected: !_isBabyBorn,
              onSelected: (sel) {
                if (sel) {
                  setState(() {
                    _isBabyBorn = false;
                    // when switch to "not born", also ensure date can't be in the past
                    final now = DateTime.now();
                    if (_selectedDate.isBefore(now)) {
                      _selectedDate = now;
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text(
                'Baby already born\n(Use check-in date)',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
              ),
              selected: _isBabyBorn,
              onSelected: (sel) {
                if (sel) {
                  setState(() {
                    _isBabyBorn = true;
                    // allow recent past dates when baby already born
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerTile() {
    final String label = _isBabyBorn
        ? 'Check-in / baby birth date'
        : 'Expected due date';

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6D3D4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Color(0xFFC2868B)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String key, String label,
      {required Icon icon}) {
    final bool selected = _paymentMethod == key;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6D3D4)),
        color: Colors.white,
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC2868B)),
              ),
              child: Center(
                child: selected
                    ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFC2868B),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
            icon,
          ],
        ),
        title: Text(label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
        onTap: () => setState(() => _paymentMethod = key),
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFC2868B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120, top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.selectedPackages.map(_buildPackageCard).toList(),
            const SizedBox(height: 8),

            // Baby status
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Baby status',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
            _buildBabyStatusToggle(),

            const SizedBox(height: 12),

            // Stay length
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Confinement duration',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
            _buildConfinementPeriodSelector(),

            const SizedBox(height: 12),

            // Date picker
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Date selection',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
            _buildDatePickerTile(),

            const SizedBox(height: 12),

            // Payment method
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Choose Payment Method',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
            _buildPaymentMethodTile('card', 'Credit / Debit Card',
                icon: const Icon(Icons.credit_card, color: Color(0xFFC2868B))),
            _buildPaymentMethodTile('fpx', 'Online Banking (FPX)',
                icon:
                const Icon(Icons.account_balance, color: Color(0xFFC2868B))),
            _buildPaymentMethodTile(
                'ewallet', 'E-Wallet (TnG, GrabPay, etc.)',
                icon: const Icon(Icons.account_balance_wallet,
                    color: Color(0xFFC2868B))),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600)),
                  Text(
                    _formatCurrency(_totalPayable),
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFADADD),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                          color: Colors.black26, width: 1.2),
                    ),
                    elevation: 3,
                    shadowColor: Colors.black26,
                  ),
                  onPressed: _isLoading ? null : _onCheckoutPressed,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                    'Check Out',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension RippleExt on Widget {
  Widget rippleTap(VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: this,
    );
  }
}
