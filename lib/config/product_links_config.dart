class ProductLinksConfig {
  const ProductLinksConfig({
    this.websiteUrl = '',
    this.telegramSignalsUrl = '',
    this.telegramCommunityUrl = '',
    this.telegramSupportUrl = '',
    this.supportEmail = '',
    this.documentationUrl = '',
    this.changelogUrl = '',
    this.privacyUrl = '',
    this.termsUrl = '',
  });

  static const ProductLinksConfig current = ProductLinksConfig();

  final String websiteUrl;
  final String telegramSignalsUrl;
  final String telegramCommunityUrl;
  final String telegramSupportUrl;
  final String supportEmail;
  final String documentationUrl;
  final String changelogUrl;
  final String privacyUrl;
  final String termsUrl;
}
