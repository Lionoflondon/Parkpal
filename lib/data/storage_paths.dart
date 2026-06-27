class ParkPalStoragePaths {
  const ParkPalStoragePaths._();

  static String signOriginal(String signId) =>
      'parkpal/signs/$signId/original.jpg';

  static String signThumbnail(String signId) =>
      'parkpal/signs/$signId/thumb.jpg';

  static String reportPhoto(String reportId) =>
      'parkpal/reports/$reportId/photo.jpg';
}
