import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

class InvoiceLine {
  const InvoiceLine({
    required this.invoiceNumber,
    this.termName,
    this.issueDate,
    this.dueDate,
    this.total,
    this.paid,
    this.balance,
    this.isPaid = false,
    this.isOverdue = false,
  });

  final String invoiceNumber;
  final String? termName;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double? total;
  final double? paid;
  final double? balance;
  final bool isPaid;
  final bool isOverdue;

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        invoiceNumber: asString(j['invoice_number']) ?? '',
        termName: asString(j['term_name']),
        issueDate: asDate(j['issue_date']),
        dueDate: asDate(j['due_date']),
        total: asDouble(j['total']),
        paid: asDouble(j['paid']),
        balance: asDouble(j['balance']),
        isPaid: asBool(j['is_paid']),
        isOverdue: asBool(j['is_overdue']),
      );
}

/// The student's fee statement, from `GET /invoices/me/`: every
/// non-cancelled invoice and the running totals.
class FeeStatement {
  const FeeStatement({required this.invoices, this.totalBilled, this.totalPaid, this.balance});
  final List<InvoiceLine> invoices;
  final double? totalBilled;
  final double? totalPaid;
  final double? balance;

  bool get hasFees => invoices.isNotEmpty;
  bool get anyOverdue => invoices.any((i) => i.isOverdue && !i.isPaid);

  /// The earliest due date among unpaid invoices.
  DateTime? get nextDue {
    final due = invoices.where((i) => !i.isPaid && i.dueDate != null).map((i) => i.dueDate!).toList()..sort();
    return due.isEmpty ? null : due.first;
  }

  factory FeeStatement.fromJson(Map<String, dynamic> j) => FeeStatement(
        invoices: asMapList(j['invoices']).map(InvoiceLine.fromJson).toList(),
        totalBilled: asDouble(j['total_billed']),
        totalPaid: asDouble(j['total_paid']),
        balance: asDouble(j['balance']),
      );
}

class FeesRepository {
  FeesRepository(this._dio);
  final Dio _dio;

  Future<FeeStatement> statement() => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/invoices/me/');
        return FeeStatement.fromJson(res.data!);
      });
}

final feesRepositoryProvider = Provider.autoDispose((ref) => FeesRepository(sessionDio(ref)));

final feeStatementProvider =
    FutureProvider.autoDispose<FeeStatement>((ref) => ref.watch(feesRepositoryProvider).statement());
