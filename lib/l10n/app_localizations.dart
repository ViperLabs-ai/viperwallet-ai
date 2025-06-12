import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Viper Wallet'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your Solana wallet'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @nft.
  ///
  /// In en, this message translates to:
  /// **'NFT'**
  String get nft;

  /// No description provided for @charts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get charts;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @mnemonicPhrase.
  ///
  /// In en, this message translates to:
  /// **'Mnemonic Phrase'**
  String get mnemonicPhrase;

  /// No description provided for @mnemonicHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your mnemonic phrase'**
  String get mnemonicHint;

  /// No description provided for @mnemonicHintExpanded.
  ///
  /// In en, this message translates to:
  /// **'Enter your mnemonic words (12 or 24 words)'**
  String get mnemonicHintExpanded;

  /// No description provided for @mnemonicRequired.
  ///
  /// In en, this message translates to:
  /// **'Mnemonic phrase is required'**
  String get mnemonicRequired;

  /// No description provided for @invalidMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Invalid mnemonic phrase'**
  String get invalidMnemonic;

  /// No description provided for @unsecureEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Unsecure environment detected'**
  String get unsecureEnvironment;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login error'**
  String get loginError;

  /// No description provided for @securityInfo.
  ///
  /// In en, this message translates to:
  /// **'Your mnemonic phrase is encrypted and stored securely on your device'**
  String get securityInfo;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy Address'**
  String get copyAddress;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard'**
  String get addressCopied;

  /// No description provided for @transactionSignatureCopied.
  ///
  /// In en, this message translates to:
  /// **'Transaction signature copied'**
  String get transactionSignatureCopied;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @totalTransactions.
  ///
  /// In en, this message translates to:
  /// **'Total Transactions'**
  String get totalTransactions;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'transactions'**
  String get transactions;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @firstTransactionWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your first transaction will appear here'**
  String get firstTransactionWillAppearHere;

  /// No description provided for @successfulTransaction.
  ///
  /// In en, this message translates to:
  /// **'Successful Transaction'**
  String get successfulTransaction;

  /// No description provided for @failedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Failed Transaction'**
  String get failedTransaction;

  /// No description provided for @transactionSignature.
  ///
  /// In en, this message translates to:
  /// **'Transaction Signature'**
  String get transactionSignature;

  /// No description provided for @slot.
  ///
  /// In en, this message translates to:
  /// **'Slot'**
  String get slot;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @finalized.
  ///
  /// In en, this message translates to:
  /// **'Finalized'**
  String get finalized;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @sol.
  ///
  /// In en, this message translates to:
  /// **'SOL'**
  String get sol;

  /// No description provided for @usd.
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get usd;

  /// No description provided for @twentyFourHours.
  ///
  /// In en, this message translates to:
  /// **'24 Hours'**
  String get twentyFourHours;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @marketCap.
  ///
  /// In en, this message translates to:
  /// **'Market Cap'**
  String get marketCap;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @memo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memo;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @loadingBalance.
  ///
  /// In en, this message translates to:
  /// **'Loading balance...'**
  String get loadingBalance;

  /// No description provided for @balanceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Balance loaded'**
  String get balanceLoaded;

  /// No description provided for @balanceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Balance could not be loaded: Check network connection'**
  String get balanceLoadFailed;

  /// No description provided for @loadingPriceData.
  ///
  /// In en, this message translates to:
  /// **'Loading price data...'**
  String get loadingPriceData;

  /// No description provided for @priceDataLoaded.
  ///
  /// In en, this message translates to:
  /// **'Price data loaded'**
  String get priceDataLoaded;

  /// No description provided for @loadingTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Loading transaction history...'**
  String get loadingTransactionHistory;

  /// No description provided for @transactionHistoryLoaded.
  ///
  /// In en, this message translates to:
  /// **'Transaction history loaded'**
  String get transactionHistoryLoaded;

  /// No description provided for @marketData.
  ///
  /// In en, this message translates to:
  /// **'Market Data'**
  String get marketData;

  /// No description provided for @solPrice.
  ///
  /// In en, this message translates to:
  /// **'SOL Price'**
  String get solPrice;

  /// No description provided for @dailyVolume.
  ///
  /// In en, this message translates to:
  /// **'Daily Volume'**
  String get dailyVolume;

  /// No description provided for @transactionCount.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionCount;

  /// No description provided for @priceChanges.
  ///
  /// In en, this message translates to:
  /// **'Price Changes'**
  String get priceChanges;

  /// No description provided for @networkConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed. Running in offline mode.'**
  String get networkConnectionFailed;

  /// No description provided for @noNetworkConnection.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Running in offline mode.'**
  String get noNetworkConnection;

  /// No description provided for @walletAddress.
  ///
  /// In en, this message translates to:
  /// **'Wallet Address'**
  String get walletAddress;

  /// No description provided for @successful.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successful;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @sendSOL.
  ///
  /// In en, this message translates to:
  /// **'Send SOL'**
  String get sendSOL;

  /// No description provided for @receiveSOL.
  ///
  /// In en, this message translates to:
  /// **'Receive SOL'**
  String get receiveSOL;

  /// No description provided for @scanQRCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQRCode;

  /// No description provided for @invalidSolanaAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid Solana address'**
  String get invalidSolanaAddress;

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get insufficientBalance;

  /// No description provided for @maxAmount.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get maxAmount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @transactionNote.
  ///
  /// In en, this message translates to:
  /// **'Transaction note'**
  String get transactionNote;

  /// No description provided for @secureTransfer.
  ///
  /// In en, this message translates to:
  /// **'Secure Transfer'**
  String get secureTransfer;

  /// No description provided for @scanToReceive.
  ///
  /// In en, this message translates to:
  /// **'Scan to receive'**
  String get scanToReceive;

  /// No description provided for @shareAddress.
  ///
  /// In en, this message translates to:
  /// **'Share address'**
  String get shareAddress;

  /// No description provided for @customizeQR.
  ///
  /// In en, this message translates to:
  /// **'Customize QR'**
  String get customizeQR;

  /// No description provided for @securityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// No description provided for @qrCodeInfo.
  ///
  /// In en, this message translates to:
  /// **'Share this QR code only with trusted people. This can be used to send SOL to your wallet.'**
  String get qrCodeInfo;

  /// No description provided for @liveCharts.
  ///
  /// In en, this message translates to:
  /// **'Live Charts'**
  String get liveCharts;

  /// No description provided for @priceMovement.
  ///
  /// In en, this message translates to:
  /// **'Price Movement'**
  String get priceMovement;

  /// No description provided for @scrollable.
  ///
  /// In en, this message translates to:
  /// **'Scrollable'**
  String get scrollable;

  /// No description provided for @highestPrice.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get highestPrice;

  /// No description provided for @lowestPrice.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get lowestPrice;

  /// No description provided for @averagePrice.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get averagePrice;

  /// No description provided for @volatility.
  ///
  /// In en, this message translates to:
  /// **'Volatility'**
  String get volatility;

  /// No description provided for @dataPoints.
  ///
  /// In en, this message translates to:
  /// **'Data Points'**
  String get dataPoints;

  /// No description provided for @liveDataPoints.
  ///
  /// In en, this message translates to:
  /// **'live data points'**
  String get liveDataPoints;

  /// No description provided for @updateInterval.
  ///
  /// In en, this message translates to:
  /// **'10s update'**
  String get updateInterval;

  /// No description provided for @nftCollection.
  ///
  /// In en, this message translates to:
  /// **'NFT Collection'**
  String get nftCollection;

  /// No description provided for @noNFTsFound.
  ///
  /// In en, this message translates to:
  /// **'No NFTs found'**
  String get noNFTsFound;

  /// No description provided for @noNFTsInWallet.
  ///
  /// In en, this message translates to:
  /// **'No NFTs in this wallet yet'**
  String get noNFTsInWallet;

  /// No description provided for @nftLoadingError.
  ///
  /// In en, this message translates to:
  /// **'Error loading NFTs'**
  String get nftLoadingError;

  /// No description provided for @checkInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get checkInternetConnection;

  /// No description provided for @nftDetails.
  ///
  /// In en, this message translates to:
  /// **'NFT Details'**
  String get nftDetails;

  /// No description provided for @mintAddress.
  ///
  /// In en, this message translates to:
  /// **'Mint Address'**
  String get mintAddress;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @attributes.
  ///
  /// In en, this message translates to:
  /// **'Attributes'**
  String get attributes;

  /// No description provided for @rarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get rarity;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @common.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get common;

  /// No description provided for @uncommon.
  ///
  /// In en, this message translates to:
  /// **'Uncommon'**
  String get uncommon;

  /// No description provided for @rare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rare;

  /// No description provided for @legendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get legendary;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @estimatedFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated Fee'**
  String get estimatedFee;

  /// No description provided for @recipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient Address'**
  String get recipientAddress;

  /// No description provided for @enterRecipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter Solana wallet address'**
  String get enterRecipientAddress;

  /// No description provided for @amountInSOL.
  ///
  /// In en, this message translates to:
  /// **'Amount (SOL)'**
  String get amountInSOL;

  /// No description provided for @memoOptional.
  ///
  /// In en, this message translates to:
  /// **'Memo (Optional)'**
  String get memoOptional;

  /// No description provided for @transactionMemo.
  ///
  /// In en, this message translates to:
  /// **'Transaction memo (max 32 characters)'**
  String get transactionMemo;

  /// No description provided for @confirmTransaction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transaction'**
  String get confirmTransaction;

  /// No description provided for @irreversibleTransaction.
  ///
  /// In en, this message translates to:
  /// **'IRREVERSIBLE TRANSACTION'**
  String get irreversibleTransaction;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @receiver.
  ///
  /// In en, this message translates to:
  /// **'Receiver'**
  String get receiver;

  /// No description provided for @networkFee.
  ///
  /// In en, this message translates to:
  /// **'Network Fee'**
  String get networkFee;

  /// No description provided for @confirmAndSend.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM AND SEND'**
  String get confirmAndSend;

  /// No description provided for @transactionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Transaction Successful'**
  String get transactionSuccessful;

  /// No description provided for @transactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transaction Failed'**
  String get transactionFailed;

  /// No description provided for @viewInExplorer.
  ///
  /// In en, this message translates to:
  /// **'View in Explorer'**
  String get viewInExplorer;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get tokens;

  /// No description provided for @addToken.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addToken;

  /// No description provided for @getQuote.
  ///
  /// In en, this message translates to:
  /// **'Get Quote'**
  String get getQuote;

  /// No description provided for @noLiquidity.
  ///
  /// In en, this message translates to:
  /// **'No liquidity available'**
  String get noLiquidity;

  /// No description provided for @pairNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Trading pair not supported'**
  String get pairNotSupported;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
