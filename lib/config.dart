class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const publicUrl = String.fromEnvironment('UPC_PUBLIC_URL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const supportPhone = String.fromEnvironment('SUPPORT_PHONE');
  static const redirect = 'com.upc.calculator://login-callback/';
  static bool get configured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
