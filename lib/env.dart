import 'package:envied/envied.dart';

part 'env.g.dart';

/// Credenciales incrustadas al compilar desde el .env de la máquina de
/// compilación (acuerdo v1 §3.7). Nunca registrar ni loguear estos valores.
@Envied(path: '.env', requireEnvFile: true)
abstract class Env {
  @EnviedField(varName: 'DRIVE_CLIENT_ID', obfuscate: true)
  static final String driveClientId = _Env.driveClientId;

  @EnviedField(varName: 'DRIVE_CLIENT_SECRET', obfuscate: true)
  static final String driveClientSecret = _Env.driveClientSecret;

  @EnviedField(varName: 'DRIVE_REFRESH_TOKEN', obfuscate: true)
  static final String driveRefreshToken = _Env.driveRefreshToken;
}
