import 'package:flutter_test/flutter_test.dart';
import 'package:apexbooks/data/workspace_catalog.dart';

void main() {
  test('workspace catalog uses current backend routes', () {
    expect(workspaceCatalog['sales-returns']!.endpoint, '/returns/sales');
    expect(workspaceCatalog['purchase-returns']!.endpoint, '/returns/purchase');
    expect(workspaceCatalog['payments']!.endpoint, '/payments/receipts');
    expect(
      workspaceCatalog['bill-payments']!.endpoint,
      '/payments/disbursements',
    );
  });

  test('transaction document workspaces use the tax document editor', () {
    for (final id in [
      'proforma',
      'sales-orders',
      'challans',
      'bills',
      'purchase-orders',
    ]) {
      expect(
        workspaceCatalog[id]!.editor,
        WorkspaceEditor.taxDocument,
        reason: id,
      );
      expect(workspaceCatalog[id]!.documentKind, isNotNull, reason: id);
    }
  });
}
