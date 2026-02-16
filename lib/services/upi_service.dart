import 'package:flutter/foundation.dart';
import 'package:upi_pay/upi_pay.dart';

class UPIService {
  // Singleton pattern (optional but good for services)
  static final UPIService _instance = UPIService._internal();
  factory UPIService() => _instance;
  UPIService._internal();

  /// Returns a list of installed UPI apps on the device
  Future<List<ApplicationMeta>> getInstalledUpiApps() async {
    try {
      return await UpiPay.getInstalledUpiApplications(
        statusType: UpiApplicationDiscoveryAppStatusType.all,
      );
    } catch (e) {
      debugPrint('Error getting UPI apps: $e');
      return [];
    }
  }

  /// Initiates a UPI transaction
  /// Returns a UpiTransactionResponse or throws an exception
  Future<UpiTransactionResponse> initiateTransaction({
    required ApplicationMeta app,
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
    String? transactionRefId,
  }) async {
    // Basic validation
    if (receiverUpiId.isEmpty || !receiverUpiId.contains('@')) {
      throw 'Invalid UPI ID';
    }

    try {
      final response = await UpiPay.initiateTransaction(
        amount: amount.toStringAsFixed(2),
        app: app.upiApplication,
        receiverName: receiverName,
        receiverUpiAddress: receiverUpiId,
        transactionRef: transactionRefId,
        transactionNote: transactionNote,
      );

      return response;
    } catch (e) {
      debugPrint('UPI Transaction Error: $e');
      rethrow;
    }
  }

  /// Helper to check if response is successful
  bool isTransactionSuccessful(UpiTransactionResponse response) {
    return response.status == UpiTransactionStatus.success;
  }

  /// Helper to get a readable status message
  String getStatusMessage(UpiTransactionResponse response) {
    switch (response.status) {
      case UpiTransactionStatus.success:
        return 'Transaction Successful';
      case UpiTransactionStatus.submitted:
        return 'Transaction Submitted (Processing)';
      case UpiTransactionStatus.failure:
        return 'Transaction Failed';
      case UpiTransactionStatus.userCancelled:
        return 'Transaction Cancelled'; // Typo in plugin enum usually
      default:
        return 'Unknown Status';
    }
  }
}
