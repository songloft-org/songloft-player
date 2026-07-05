import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/secure_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageService.cachedAccessToken = null;
    SecureStorageService.cachedRefreshToken = null;
  });

  test('saveTokens syncs the requested wallet', () async {
    final storage = SecureStorageService();

    await storage.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresIn: 3600,
      walletKey: 'server-a',
    );
    await storage.clearTokens();

    final restored = await storage.restoreWallet('server-a');

    expect(restored, isTrue);
    expect(await storage.getAccessToken(), 'access-token');
    expect(await storage.getRefreshToken(), 'refresh-token');
    expect(await storage.isAccessTokenExpired(), isFalse);
  });

  test('saveTokens overwrites stale wallet tokens after refresh', () async {
    final storage = SecureStorageService();

    await storage.saveTokens(
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      expiresIn: 3600,
      walletKey: SecureStorageService.localWalletKey,
    );
    await storage.saveTokens(
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      expiresIn: 3600,
      walletKey: SecureStorageService.localWalletKey,
    );
    await storage.clearTokens();

    final restored = await storage.restoreWallet(
      SecureStorageService.localWalletKey,
    );

    expect(restored, isTrue);
    expect(await storage.getAccessToken(), 'new-access-token');
    expect(await storage.getRefreshToken(), 'new-refresh-token');
  });

  test('clearWallet removes a bad archived session', () async {
    final storage = SecureStorageService();

    await storage.saveTokens(
      accessToken: 'bad-access-token',
      refreshToken: 'bad-refresh-token',
      expiresIn: 3600,
      walletKey: 'server-a',
    );
    await storage.clearWallet('server-a');
    await storage.clearTokens();

    final restored = await storage.restoreWallet('server-a');

    expect(restored, isFalse);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });
}
