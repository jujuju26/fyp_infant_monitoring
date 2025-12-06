const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.ipay88Response = functions.https.onRequest(async (req, res) => {
  const paymentData = req.body;

  // Payment verification request to iPay88 API
  const verificationData = {
    merchant_code: 'YOUR_MERCHANT_CODE',
    order_id: paymentData.order_id,
    transaction_id: paymentData.transaction_id,
    amount: paymentData.amount,
    status: paymentData.status, // or any other fields iPay88 sends
  };

  try {
    // Send a request to verify the payment (check iPay88 API docs for the correct endpoint)
    const response = await axios.post('https://sandbox.ipay88.com.my/payment/verify', verificationData);
    const verificationResult = response.data;

    // Process the payment status
    if (verificationResult.status === 'success') {
      // Handle success: update the database, send a confirmation to the user, etc.
      res.status(200).send('Payment successful');
    } else {
      // Handle failure: inform the user, log the error, etc.
      res.status(400).send('Payment failed');
    }
  } catch (error) {
    console.error('Payment verification error:', error);
    res.status(500).send('Error verifying payment');
  }
});
