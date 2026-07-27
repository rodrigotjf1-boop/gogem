import 'package:flutter_test/flutter_test.dart';
import 'package:gogem_kiosk/data/catalog/catalog_repository.dart';
import 'package:gogem_kiosk/data/db/kiosk_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures.dart';

void main() {
  late CatalogRepository repo;
  setUpAll(() => sqfliteFfiInit());
  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await KioskDatabase.ensureSchema(db);
    repo = CatalogRepository(db);
  });

  test('roundtrip salvar/carregar + versão corrente', () async {
    expect(await repo.versaoCorrente(), isNull);
    await repo.salvarSnapshot(publicadoFixture);
    expect(await repo.versaoCorrente(), 3);
    final m = await repo.carregarCorrente();
    expect(m!.produtos, hasLength(3));
  });

  test('retenção mantém só as 3 versões mais recentes', () async {
    for (final v in [1, 2, 3, 4, 5]) {
      await repo
          .salvarSnapshot({...publicadoFixture, 'versao': v});
    }
    expect(await repo.versaoCorrente(), 5);
    // versão 1 e 2 foram podadas — corrente segue íntegra
    final m = await repo.carregarCorrente();
    expect(m!.versao, 5);
  });
}
