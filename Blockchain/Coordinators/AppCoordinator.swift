//
//  AppCoordinator.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import PlatformUIKit
import PlatformKit

/// TODO: This class should be refactored so any view would load
/// as late as possible and also would be deallocated when is no longer in use
/// TICKET: https://blockchain.atlassian.net/browse/IOS-2619
@objc class AppCoordinator: NSObject, Coordinator, MainFlowProviding {
    
    // MARK: - Properties

    static let shared = AppCoordinator()
    
    // class function declared so that the AppCoordinator singleton can be accessed from obj-C
    @objc class func sharedInstance() -> AppCoordinator {
        return AppCoordinator.shared
    }

    // MARK: - Services
    
    /// Onboarding router
    let onboardingRouter: OnboardingRouter
    
    weak var window: UIWindow!

    private let authenticationCoordinator: AuthenticationCoordinator
    private let blockchainSettings: BlockchainSettings.App
    private let walletManager: WalletManager
    private let paymentPresenter: PaymentPresenter
    private let loadingViewPresenter: LoadingViewPresenting
    private lazy var appFeatureConfigurator: AppFeatureConfigurator = { appFeatureConfiguratorProvider() }()
    private let appFeatureConfiguratorProvider: () -> AppFeatureConfigurator

    let airdropRouter: AirdropRouterAPI
    private var settingsRouterAPI: SettingsRouterAPI?
    private var simpleBuyRouter: SimpleBuyRouterAPI!

    // MARK: - UIViewController Properties
    
    @objc var slidingViewController: ECSlidingViewController!
    @objc var tabControllerManager = TabControllerManager.makeFromStoryboard()
    private(set) var sideMenuViewController: SideMenuViewController!
    private let disposeBag = DisposeBag()
    
    private lazy var accountsAndAddressesNavigationController: AccountsAndAddressesNavigationController = { [unowned self] in
        let storyboard = UIStoryboard(name: "AccountsAndAddresses", bundle: nil)
        let viewController = storyboard.instantiateViewController(
            withIdentifier: "AccountsAndAddressesNavigationController"
        ) as! AccountsAndAddressesNavigationController
        viewController.modalPresentationStyle = .fullScreen
        viewController.modalTransitionStyle = .coverVertical
        return viewController
    }()

    // MARK: NSObject

    private init(authenticationCoordinator: AuthenticationCoordinator = .shared,
                 blockchainSettings: BlockchainSettings.App = .shared,
                 onboardingRouter: OnboardingRouter = OnboardingRouter(),
                 walletManager: WalletManager = WalletManager.shared,
                 paymentPresenter: PaymentPresenter = PaymentPresenter(),
                 airdropRouter: AirdropRouterAPI = AirdropRouter(topMostViewControllerProvider: UIApplication.shared),
                 loadingViewPresenter: LoadingViewPresenting = LoadingViewPresenter.shared,
                 appFeatureConfiguratorProvider: @escaping () -> AppFeatureConfigurator = { AppFeatureConfigurator.shared }) {
        self.airdropRouter = airdropRouter
        self.authenticationCoordinator = authenticationCoordinator
        self.blockchainSettings = blockchainSettings
        self.onboardingRouter = onboardingRouter
        self.walletManager = walletManager
        self.paymentPresenter = paymentPresenter
        self.loadingViewPresenter = loadingViewPresenter
        self.appFeatureConfiguratorProvider = appFeatureConfiguratorProvider
        super.init()
        self.walletManager.accountInfoAndExchangeRatesDelegate = self
        self.walletManager.backupDelegate = self
        self.walletManager.historyDelegate = self
        observeSymbolChanges()
    }

    // MARK: Public Methodsº

    func startAfterWalletCreation() {
        window.rootViewController?.dismiss(animated: true, completion: nil)
        setupMainFlow(forced: true)
        window.rootViewController = slidingViewController
        tabControllerManager.dashBoardClicked(nil)
    }
    
    @objc func start() {
        appFeatureConfigurator.initialize()
        BuySellCoordinator.shared.start()

        // Display welcome screen if no wallet is authenticated
        if blockchainSettings.guid == nil || blockchainSettings.sharedKey == nil {
            onboardingRouter.start()
        } else {
            AuthenticationCoordinator.shared.start()
        }
    }

    /// Shows an upgrade to HD wallet prompt if the user has a legacy wallet
    @objc func showHdUpgradeViewIfNeeded() {
        guard walletManager.wallet.isInitialized() else { return }
        guard !walletManager.wallet.didUpgradeToHd() else { return }
        showHdUpgradeView()
    }

    /// Shows the HD wallet upgrade view
    func showHdUpgradeView() {
        let storyboard = UIStoryboard(name: "Upgrade", bundle: nil)
        let upgradeViewController = storyboard.instantiateViewController(withIdentifier: "UpgradeViewController")
        upgradeViewController.modalPresentationStyle = .fullScreen
        upgradeViewController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.present(
            upgradeViewController,
            animated: true
        )
    }

    @discardableResult
    func setupMainFlow(forced: Bool) -> UIViewController {
        let setupAndReturnSideMenuController = { [unowned self] () -> UIViewController in
            self.setupTabControllerManager()
            self.setupSideMenuViewController()
            let viewController = ECSlidingViewController()
            viewController.underLeftViewController = self.sideMenuViewController
            viewController.topViewController = self.tabControllerManager
            self.slidingViewController = viewController
            self.tabControllerManager.view.layoutIfNeeded()
            self.tabControllerManager.dashBoardClicked(nil)
            return viewController
        }
        
        if forced {
            return setupAndReturnSideMenuController()
        } else if let slidingViewController = slidingViewController {
            return slidingViewController
        } else {
            return setupAndReturnSideMenuController()
        }
    }

    private func setupSideMenuViewController() {
        let viewController = SideMenuViewController.makeFromStoryboard()
        viewController.delegate = self
        self.sideMenuViewController = viewController
    }
    
    private func setupTabControllerManager() {
        let tabControllerManager = TabControllerManager.makeFromStoryboard()
        self.tabControllerManager = tabControllerManager
    }

    @objc func showBackupView() {
        let storyboard = UIStoryboard(name: "Backup", bundle: nil)
        let backupController = storyboard.instantiateViewController(withIdentifier: "BackupNavigation") as! BackupNavigationViewController
        backupController.wallet = walletManager.wallet
        backupController.modalPresentationStyle = .fullScreen
        backupController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(backupController, animated: true)
    }

    func showSettingsView() {
        settingsRouterAPI = SettingsRouter(currencyRouting: self, tabSwapping: self)
        settingsRouterAPI?.presentSettings()
    }

    @objc func closeSideMenu() {
        guard let slidingViewController = slidingViewController else {
            return
        }
        guard slidingViewController.currentTopViewPosition != .centered else {
            return
        }
        slidingViewController.resetTopView(animated: true)
    }

    /// Reloads contained view controllers
    @objc func reload() {
        tabControllerManager.reload()
        accountsAndAddressesNavigationController.reload()
        sideMenuViewController?.reload()
        
        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)

        // Legacy code for generating new addresses
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
    }

    /// Method to "cleanup" state when the app is backgrounded.
    func cleanupOnAppBackgrounded() {
        
        /// Keep going only if the user is logged in
        guard slidingViewController != nil else {
            return
        }
        tabControllerManager.hideSendAndReceiveKeyboards()
        tabControllerManager.transactionsBitcoinViewController?.loadedAllTransactions = false
        tabControllerManager.transactionsBitcoinViewController?.messageIdentifier = nil
        tabControllerManager.dashBoardClicked(nil)
        closeSideMenu()
    }

    /// Observes symbol changes so that view controllers can reflect the new symbol
    private func observeSymbolChanges() {
        BlockchainSettings.App.shared.onSymbolLocalChanged = { [unowned self] _ in
            self.tabControllerManager.reloadSymbols()
            self.accountsAndAddressesNavigationController.reload()
            self.sideMenuViewController?.reload()
        }
    }

    func reloadAfterMultiAddressResponse() {
        if WalletManager.shared.wallet.didReceiveMessageForLastTransaction {
            WalletManager.shared.wallet.didReceiveMessageForLastTransaction = false
            if let transaction = WalletManager.shared.latestMultiAddressResponse?.transactions.firstObject as? Transaction {
                tabControllerManager.receiveBitcoinViewController?.paymentReceived(UInt64(abs(transaction.amount)))
            }
        }
        
        tabControllerManager.reloadAfterMultiAddressResponse()
        accountsAndAddressesNavigationController.reload()
        sideMenuViewController?.reload()

        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.multiAddressResponseReload, object: nil)
    }
}

extension AppCoordinator: SideMenuViewControllerDelegate {
    func sideMenuViewController(_ viewController: SideMenuViewController, didTapOn item: SideMenuItem) {
        switch item {
        case .upgrade:
            handleUpgrade()
        case .backup:
            handleBackup()
        case .accountsAndAddresses:
            handleAccountsAndAddresses()
        case .settings:
            handleSettings()
        case .webLogin:
            handleWebLogin()
        case .support:
            handleSupport()
        case .airdrops:
            handleAirdrops()
        case .logout:
            handleLogout()
        case .buyBitcoin:
            handleBuyCrypto(simpleBuy: false)
        case .simpleBuy:
            handleBuyCrypto(simpleBuy: true)
        case .exchange:
            handleExchange()
        case .lockbox:
            let storyboard = UIStoryboard(name: "LockboxViewController", bundle: nil)
            let lockboxViewController = storyboard.instantiateViewController(withIdentifier: "LockboxViewController") as! LockboxViewController
            lockboxViewController.modalPresentationStyle = .fullScreen
            lockboxViewController.modalTransitionStyle = .coverVertical
            UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(lockboxViewController, animated: true)
        }
    }

    private func handleAirdrops() {
        airdropRouter.presentAirdropCenterScreen()
    }
    
    private func handleUpgrade() {
        AppCoordinator.shared.showHdUpgradeView()
    }

    private func handleBackup() {
        showBackupView()
    }

    private func handleAccountsAndAddresses() {
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            accountsAndAddressesNavigationController,
            animated: true
        ) { [weak self] in
            guard let strongSelf = self else { return }

            let wallet = strongSelf.walletManager.wallet

            guard !BlockchainSettings.App.shared.hideTransferAllFundsAlert &&
                strongSelf.accountsAndAddressesNavigationController.viewControllers.count == 1 &&
                wallet.didUpgradeToHd() &&
                wallet.getTotalBalanceForSpendableActiveLegacyAddresses() >= wallet.dust() &&
                strongSelf.accountsAndAddressesNavigationController.assetSelectorView().selectedAsset == .bitcoin else {
                    return
            }

            strongSelf.accountsAndAddressesNavigationController.alertUser(toTransferAllFunds: false)
        }
    }

    private func handleSettings() {
        showSettingsView()
    }
    
    private func handleExchange() {
        ExchangeCoordinator.shared.start(from: tabControllerManager)
    }

    private func handleWebLogin() {
        let presenter = WebLoginScreenPresenter()
        let viewController = WebLoginScreenViewController(presenter: presenter)
        let navigationViewController = BCNavigationController(
            rootViewController: viewController,
            title: LocalizationConstants.SideMenu.loginToWebWallet
        )
        navigationViewController.modalPresentationStyle = .fullScreen
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            navigationViewController,
            animated: true
        )
    }

    private func handleSupport() {
        let title = String(format: LocalizationConstants.openArg, Constants.Url.blockchainSupport)
        let alert = UIAlertController(
            title: title,
            message: LocalizationConstants.youWillBeLeavingTheApp,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.continueString, style: .default) { _ in
                guard let url = URL(string: Constants.Url.blockchainSupport) else { return }
                UIApplication.shared.open(url)
            }
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
        )
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }

    private func handleLogout() {
        let alert = UIAlertController(
            title: LocalizationConstants.SideMenu.logout,
            message: LocalizationConstants.SideMenu.logoutConfirm,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.okString, style: .default) { _ in
                AuthenticationCoordinator.shared.logout()
            }
        )
        alert.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel))
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }
    
    func clearOnLogout() {
        slidingViewController = nil
        sideMenuViewController = nil
    }

    /// Starts Coinify or Simple Buy flow.
    func handleBuyCrypto(simpleBuy: Bool) {
        /// Starts Coinify flow
        func startBuyCrypto() {
            BuySellCoordinator.shared.showBuyBitcoinView()
        }
        /// Starts Simple Buy Flow
        func startSimpleBuy() {
            let stateService = SimpleBuyStateService()
            simpleBuyRouter = SimpleBuyRouter(stateService: stateService)
            simpleBuyRouter.start()
        }
        if simpleBuy {
            startSimpleBuy()
        } else {
            startBuyCrypto()
            // TODO: IOS-2833 - Remove previous line and uncomment following code to disable Coinify once Simple Buy is ready for release.
            // AlertViewPresenter.shared.standardNotify(
            //   message: LocalizationConstants.BuySell.DeprecationError.message,
            //   title: LocalizationConstants.Errors.error,
            //   actions: [
            //     UIAlertAction(title: LocalizationConstants.okString, style: .default)
            //   ]
            // )
        }
    }
    
    func startSimpleBuyAtLogin() {
        let stateService = SimpleBuyStateService()
        guard !stateService.cache[.hasShownIntroScreen] else {
            return
        }
        simpleBuyRouter = SimpleBuyRouter(stateService: stateService)
        simpleBuyRouter.start()
    }

    /// Checks for simple buy flow availability, and for coinify feature flag and isBuyEnabled flag, then
    /// starts the correct Crypto Buy Flow.
    /// If no flow is available, executes onError..
    @objc
    func startBuyUsingCoinifyOrSimpleBuy(onError: @escaping () -> Void) {
        let flowAvailability = SimpleBuyServiceProvider.default.flowAvailability
        flowAvailability
            .isSimpleBuyFlowAvailable
            .take(1)
            .asSingle()
            .handleLoaderForLifecycle(
                loader: loadingViewPresenter,
                style: .circle
            )
            .subscribe(onSuccess: { [unowned self] isEligible in
                if isEligible {
                    self.handleBuyCrypto(simpleBuy: true)
                } else if self.appFeatureConfigurator.configuration(for: .coinifyEnabled).isEnabled, self.walletManager.wallet.isBuyEnabled() {
                    self.handleBuyCrypto(simpleBuy: false)
                } else {
                    onError()
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - QRScannerRouting

extension AppCoordinator: QRScannerRouting {
    func routeToQrScanner() {
        tabControllerManager.qrCodeButtonClicked()
    }
}

// MARK: - DrawerRouting

extension AppCoordinator: DrawerRouting {
    // Shows the side menu (i.e. ECSlidingViewController)
    @objc func toggleSideMenu() {
        // If the sideMenu is not shown, show it
        if slidingViewController.currentTopViewPosition == .centered {
            slidingViewController.anchorTopViewToRight(animated: true)
        } else {
            slidingViewController.resetTopView(animated: true)
        }
        walletManager.wallet.isFetchingTransactions = false
    }
}

extension AppCoordinator: WalletAccountInfoAndExchangeRatesDelegate {
    func didGetAccountInfoAndExchangeRates() {
        loadingViewPresenter.hide()
        reloadAfterMultiAddressResponse()
    }
}

extension AppCoordinator: WalletBackupDelegate {
    func didBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }

    func didFailBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }
}

extension AppCoordinator: WalletHistoryDelegate {
    func didFailGetHistory(error: String?) {
        guard let errorMessage = error, errorMessage.count > 0 else {
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.noInternetConnectionPleaseCheckNetwork)
            return
        }
        AnalyticsService.shared.trackEvent(title: "btc_history_error", parameters: ["error": errorMessage])
        AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.balancesGeneric)
    }

    func didFetchEthHistory() {
        loadingViewPresenter.hide()
        reload()
    }

    func didFetchBitcoinCashHistory() {
        loadingViewPresenter.hide()
        reload()
    }
}

// MARK: - TabSwapping

extension AppCoordinator: TabSwapping {
    func switchToSend() {
        tabControllerManager.sendCoinsClicked(nil)
    }
    
    func switchTabToSwap() {
        tabControllerManager.swapTapped(nil)
    }
    
    func switchTabToReceive() {
        tabControllerManager.receiveCoinClicked(nil)
    }
    
    func switchToActivity(currency: CryptoCurrency) {
        switch currency {
        case .bitcoin:
            tabControllerManager.showTransactionsBitcoin()
        case .bitcoinCash:
            tabControllerManager.showTransactionsBitcoinCash()
        case .ethereum:
            tabControllerManager.showTransactionsEther()
        case .pax:
            tabControllerManager.showTransactionsPax()
        case .stellar:
            tabControllerManager.showTransactionsStellar()
        }
    }
}

extension AppCoordinator: CurrencyRouting {
    func toSend(_ currency: CryptoCurrency) {
        tabControllerManager.showSend(currency.legacy)
    }
    
    func toReceive(_ currency: CryptoCurrency) {
        tabControllerManager.showReceive(currency.legacy)
    }
}

// MARK: - DevSupporting

extension AppCoordinator: DevSupporting {
    @objc func showDebugView(from presenter: DebugViewPresenter) {
        let debugViewController = DebugTableViewController()
        debugViewController.presenter = presenter
        let navigationController = UINavigationController(rootViewController: debugViewController)
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(navigationController, animated: true)
    }
}
