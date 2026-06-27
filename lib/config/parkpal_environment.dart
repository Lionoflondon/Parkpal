enum ParkPalEnvironment {
  dev,
  staging,
  production;

  static ParkPalEnvironment fromName(String value) {
    return ParkPalEnvironment.values.firstWhere(
      (environment) => environment.name == value,
      orElse: () => ParkPalEnvironment.dev,
    );
  }
}

class ParkPalConfig {
  const ParkPalConfig({
    required this.environment,
    required this.firebaseProjectId,
    required this.firebaseStorageBucket,
    required this.firebaseRegion,
  });

  factory ParkPalConfig.fromEnvironment() {
    return ParkPalConfig(
      environment: ParkPalEnvironment.fromName(
        const String.fromEnvironment('PARKPAL_ENV', defaultValue: 'dev'),
      ),
      firebaseProjectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: 'parkpal-dev',
      ),
      firebaseStorageBucket: const String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: 'parkpal-dev.appspot.com',
      ),
      firebaseRegion: const String.fromEnvironment(
        'FIREBASE_REGION',
        defaultValue: 'europe-west2',
      ),
    );
  }

  final ParkPalEnvironment environment;
  final String firebaseProjectId;
  final String firebaseStorageBucket;
  final String firebaseRegion;
}
