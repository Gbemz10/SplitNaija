/// Common Nigerian banks and their Paystack bank codes, for the payout
/// setup screen. There's no `GET /bank` proxy on the backend yet (see
/// FRONTEND_BRIEF.md #7), so this is hardcoded as a reasonable v1 — verify
/// against Paystack's actual `GET /bank` list before relying on it in
/// production, codes do occasionally change.
class NigerianBank {
  const NigerianBank(this.name, this.code);
  final String name;
  final String code;
}

const kNigerianBanks = [
  NigerianBank('Access Bank', '044'),
  NigerianBank('Zenith Bank', '057'),
  NigerianBank('Guaranty Trust Bank (GTBank)', '058'),
  NigerianBank('United Bank for Africa (UBA)', '033'),
  NigerianBank('First Bank of Nigeria', '011'),
  NigerianBank('Fidelity Bank', '070'),
  NigerianBank('Union Bank', '032'),
  NigerianBank('Sterling Bank', '232'),
  NigerianBank('Stanbic IBTC Bank', '221'),
  NigerianBank('Wema Bank', '035'),
  NigerianBank('Polaris Bank', '076'),
  NigerianBank('Providus Bank', '101'),
  NigerianBank('Ecobank Nigeria', '050'),
  NigerianBank('First City Monument Bank (FCMB)', '214'),
  NigerianBank('Heritage Bank', '030'),
  NigerianBank('Keystone Bank', '082'),
  NigerianBank('Unity Bank', '215'),
  NigerianBank('Opay', '999992'),
  NigerianBank('Kuda Bank', '50211'),
  NigerianBank('Moniepoint MFB', '50515'),
  NigerianBank('PalmPay', '999991'),
];