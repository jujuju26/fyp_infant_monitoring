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
  DateTime _checkInDate = DateTime.now();
  String _paymentMethod = 'card';
  bool _isLoading = false;

  DateTime _addMonths(DateTime src, int monthsToAdd) {
    final int newYear = src.year + ((src.month - 1 + monthsToAdd) ~/ 12);
    final int newMonth = ((src.month - 1 + monthsToAdd) % 12) + 1;
    final int lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final int newDay =
    src.day <= lastDayOfNewMonth ? src.day : lastDayOfNewMonth;
    return DateTime(
        newYear, newMonth, newDay, src.hour, src.minute, src.second);
  }

  String _formatDate(DateTime d) => DateFormat('d MMMM yyyy').format(d);

  String _formatCurrency(double amount) => 'RM ${amount.toStringAsFixed(2)}';

  double get _totalPayable {
    double sum = 0.0;
    for (final pkg in widget.selectedPackages) {
      final price = (pkg['price'] ?? 0).toDouble();
      final quantity = pkg['quantity'] ?? 1;
      sum += price * quantity;
    }
    return sum;
  }

  Future<void> _pickCheckInDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkInDate.isBefore(now) ? now : _checkInDate,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _checkInDate = picked);
  }

  Future<void> _saveBookingToFirebase() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final bookingData = {
        'packages': widget.selectedPackages,
        'checkInDate': _checkInDate.toIso8601String(),
        'checkOutDate': _addMonths(_checkInDate, 2).toIso8601String(),
        'paymentMethod': _paymentMethod,
        'totalPayable': _totalPayable,
        'status': 'pending',
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onCheckoutPressed() async {
    setState(() => _isLoading = true);
    try {
      await _saveBookingToFirebase();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentSuccessScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final String name = pkg['name'] ?? 'Package Name';
    final String location =
        pkg['location'] ?? 'No. 45, Jalan Ampang, 50450 Kuala Lumpur';
    final double price = (pkg['price'] ?? 0).toDouble();
    final int quantity = pkg['quantity'] ?? 1;
    final DateTime checkOutDate = _addMonths(_checkInDate, 2);

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
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(child: Text(location, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.attach_money, size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Text('Price per month: ${_formatCurrency(price)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Text('Check-in: ${_formatDate(_checkInDate)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Text('Check-out: ${_formatDate(checkOutDate)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.production_quantity_limits, size: 18, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Text('Quantity: $quantity', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB77E84),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Subtotal: ${_formatCurrency(price * quantity)}',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerTile() {
    return GestureDetector(
      onTap: _pickCheckInDate,
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
            const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 10),
            Expanded(child: Text('Check-in: ${_formatDate(_checkInDate)}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14))),
            const Icon(Icons.edit, color: Color(0xFFC2868B)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String key, String label, {required Icon icon}) {
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
        title: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
        onTap: () => setState(() => _paymentMethod = key),
      ),
    );
  }

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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Choose Check-in Date', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
            _buildDatePickerTile(),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Choose Payment Method', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
            _buildPaymentMethodTile('card', 'Credit / Debit Card', icon: const Icon(Icons.credit_card, color: Color(0xFFC2868B))),
            _buildPaymentMethodTile('fpx', 'Online Banking (FPX)', icon: const Icon(Icons.account_balance, color: Color(0xFFC2868B))),
            _buildPaymentMethodTile('ewallet', 'E-Wallet (TnG, GrabPay, etc.)', icon: const Icon(Icons.account_balance_wallet, color: Color(0xFFC2868B))),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  Text(_formatCurrency(_totalPayable), style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16)),
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
                      side: const BorderSide(color: Colors.black26, width: 1.2),
                    ),
                    elevation: 3,
                    shadowColor: Colors.black26,
                  ),
                  onPressed: _onCheckoutPressed,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Check Out', style: TextStyle(fontFamily: 'Poppins', color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
