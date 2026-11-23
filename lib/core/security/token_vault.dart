import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 用 Windows 凭据管理器保存登录态。
///
/// 比"明文塞数据库"安全：凭据由系统按当前用户加密（DPAPI），
/// 换用户或换机器都读不到。也避免引入 `flutter_secure_storage`
/// （它的 Windows 实现要 ATL，本机 VS Build Tools 没装）。
class TokenVault {
  const TokenVault();

  static const String _prefix = 'anime_client:';

  Future<String?> read(String key) async {
    final targetPtr = (_prefix + key).toNativeUtf16(allocator: calloc);
    final credential = calloc<Pointer<CREDENTIAL>>();
    try {
      final result = CredRead(PCWSTR(targetPtr), CRED_TYPE_GENERIC, credential);
      if (!result.value) return null;
      final cred = credential.value.ref;
      final size = cred.CredentialBlobSize;
      if (cred.CredentialBlob == nullptr || size == 0) return null;
      final bytes = cred.CredentialBlob.asTypedList(size);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      if (credential.value != nullptr) CredFree(credential.value);
      calloc.free(credential);
      calloc.free(targetPtr);
    }
  }

  Future<void> write(String key, String value) async {
    final targetPtr = (_prefix + key).toNativeUtf16(allocator: calloc);
    final bytes = utf8.encode(value);
    final blob = calloc<Uint8>(bytes.length);
    blob.asTypedList(bytes.length).setAll(0, bytes);
    final credPtr = calloc<CREDENTIAL>();
    try {
      final cred = credPtr.ref;
      cred.Type = CRED_TYPE_GENERIC;
      cred.TargetName = PWSTR(targetPtr);
      cred.UserName = PWSTR(targetPtr);
      cred.CredentialBlobSize = bytes.length;
      cred.CredentialBlob = blob;
      cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
      final result = CredWrite(credPtr, 0);
      if (!result.value) {
        throw StateError('保存登录态失败（Win32 错误码 ${result.error}）');
      }
    } finally {
      calloc.free(credPtr);
      calloc.free(blob);
      calloc.free(targetPtr);
    }
  }

  Future<void> delete(String key) async {
    final targetPtr = (_prefix + key).toNativeUtf16(allocator: calloc);
    try {
      CredDelete(PCWSTR(targetPtr), CRED_TYPE_GENERIC);
    } finally {
      calloc.free(targetPtr);
    }
  }
}
