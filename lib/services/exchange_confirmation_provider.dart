import '../models/exchange_confirmation_models.dart';

abstract interface class ExchangeConfirmationProvider {
  Future<ExchangeConfirmationSnapshot> load(String symbol);
}
