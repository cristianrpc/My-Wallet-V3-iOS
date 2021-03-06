//
//  BillingAddressScreenViewController.swift
//  Blockchain
//
//  Created by Daniel Huri on 30/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import RxCocoa
import PlatformUIKit

final class BillingAddressScreenViewController: BaseTableViewController {

    // MARK: - Injected
    
    private let presenter: BillingAddressScreenPresenter
    
    // MARK: - Accessors
    
    private let keyboardObserver = KeyboardObserver()
    private var keyboardInteractionController: KeyboardInteractionController!
    private let disposeBag = DisposeBag()
    
    // MARK: - Setup
    
    init(presenter: BillingAddressScreenPresenter) {
        self.presenter = presenter
        super.init()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        continueButtonView.viewModel = presenter.buttonViewModel
        keyboardInteractionController = KeyboardInteractionController(in: self)
        setupTableView()
        setupKeyboardObserver()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        keyboardObserver.setup()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardObserver.remove()
    }
    
    private func setupNavigationBar() {
        self.set(
            barStyle: .lightContent(ignoresStatusBar: false, background: .navigationBarBackground),
            leadingButtonStyle: .back
        )
        titleViewStyle = .text(value: presenter.title)
    }
    
    private func setupKeyboardObserver() {
        keyboardObserver.state
            .bind(weak: self) { (self, state) in
                switch state.visibility {
                case .visible:
                    self.footerHeightConstraint.priority = .penultimateHigh
                    self.footerHeightConstraint.constant = state.payload.height
                case .hidden:
                    self.footerHeightConstraint.priority = .defaultLow
                }
                self.view.layoutIfNeeded()
            }
            .disposed(by: disposeBag)
    }
    
    private func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = false
        tableView.contentInset = .init(top: 16, left: 0, bottom: 0, right: 0)
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(SelectionButtonTableViewCell.self)
        tableView.register(TextFieldTableViewCell.self)
        tableView.register(DoubleTextFieldTableViewCell.self)
        tableView.separatorColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
                
        presenter.refresh
            .bind(weak: tableView) { $0.reloadData() }
            .disposed(by: disposeBag)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension BillingAddressScreenViewController: UITableViewDelegate, UITableViewDataSource {
            
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.presentationDataRelay.value.cellCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let presentationData = presenter.presentationDataRelay.value
        let cellType = presentationData.cellType(for: indexPath.row)
        switch cellType {
        case .textField(let type):
            return textFieldCell(
                for: indexPath.row,
                type: type
            )
        case .doubleTextField(let leadingType, let trailingType):
            return doubleTextFieldCell(
                for: indexPath.row,
                leadingType: leadingType,
                trailingType: trailingType
            )
        case .selectionView:
            return selectionButtonTableViewCell(for: indexPath.row)
        }
    }
    
    // MARK: - Accessors
    
    private func textFieldCell(for row: Int, type: TextFieldType) -> UITableViewCell {
        let cell = tableView.dequeue(
            TextFieldTableViewCell.self,
            for: IndexPath(row: row, section: 0)
        )
        cell.setup(
            viewModel: presenter.textFieldViewModelsMap[type]!,
            keyboardInteractionController: keyboardInteractionController
        )
        return cell
    }
    
    private func doubleTextFieldCell(for row: Int,
                                     leadingType: TextFieldType,
                                     trailingType: TextFieldType) -> UITableViewCell {
        let cell = tableView.dequeue(
            DoubleTextFieldTableViewCell.self,
            for: IndexPath(row: row, section: 0)
        )
        cell.setup(
            viewModel: .init(
                leading: presenter.textFieldViewModelsMap[leadingType]!,
                trailing: presenter.textFieldViewModelsMap[trailingType]!
            ),
            keyboardInteractionController: keyboardInteractionController
        )
        return cell
    }
    
    private func selectionButtonTableViewCell(for row: Int) -> UITableViewCell {
        let cell = tableView.dequeue(
            SelectionButtonTableViewCell.self,
            for: IndexPath(row: row, section: 0)
        )
        cell.viewModel = presenter.selectionButtonViewModel
        return cell
    }
}
