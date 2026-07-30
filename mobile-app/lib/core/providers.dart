import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/policies/data/repositories/policy_repository.dart';
import 'package:claimsupport/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:claimsupport/features/authentication/data/repositories/auth_repository.dart';
import 'package:claimsupport/features/prescriptions/data/repositories/prescription_repository.dart';
import 'package:claimsupport/features/analysis_reports/data/repositories/analysis_report_repository.dart';

// Repositories
final policyRepositoryProvider = Provider((ref) => PolicyRepository());
final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());
final authRepositoryProvider = Provider((ref) => AuthRepository());
final prescriptionRepositoryProvider = Provider((ref) => PrescriptionRepository());

final analysisReportRepositoryProvider = Provider((ref) => AnalysisReportRepository());
