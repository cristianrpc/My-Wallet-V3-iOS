//
//  SelectionItemViewPresenter.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 30/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import ToolKit
import PlatformKit

final class SelectionItemViewPresenter {
    
    // MARK: - Types
    
    private typealias AccessibilityId = Accessibility.Identifier.SelectionScreen
    
    // MARK: - Exposed Properties
    
    let thumb: ViewContent
    let title: LabelContent
    let description: LabelContent

    let accessibility: Accessibility
    
    var selectionImage: Observable<ImageViewContent> {
        selectionImageRelay.asObservable()
    }
        
    var data: SelectionItemViewModel {
        interactor.item
    }
    
    let tapRelay = PublishRelay<Void>()
    
    var isSelected: Observable<Bool> {
        interactor.isSelectedRelay.distinctUntilChanged()
    }
    
    // MARK: - Private Properties
    
    private let selectionImageRelay = BehaviorRelay(value: ImageViewContent.empty)
    private let isSelectedRelay = BehaviorRelay(value: false)
    private let interactor: SelectionItemViewInteractor
    private let disposeBag = DisposeBag()
    
    init(interactor: SelectionItemViewInteractor) {
        self.interactor = interactor
        let item = interactor.item
        accessibility = .id("\(AccessibilityId.selectionCellPrefix)\(item.id)")
        switch item.thumb {
        case .name(let name):
            thumb = .image(
                ImageViewContent(
                    imageName: name,
                    accessibility: .id("\(AccessibilityId.imageViewPrefix)\(item.accessibilityId)")
                )
            )
        case .emoji(let value):
            thumb = .label(
                LabelContent(
                    text: value,
                    font: .mainMedium(30),
                    color: .black,
                    accessibility: .id("\(AccessibilityId.imageViewPrefix)\(item.accessibilityId)")
                )
            )
        case .none:
            thumb = .none
        }

        title = LabelContent(
            text: item.title,
            font: .mainSemibold(16),
            color: .titleText,
            accessibility: .id("\(AccessibilityId.titleLabelPrefix)\(item.accessibilityId)")
        )
        description = LabelContent(
            text: item.subtitle,
            font: .mainMedium(14),
            color: .titleText,
            accessibility: .id("\(AccessibilityId.descriptionLabelPrefix)\(item.accessibilityId)")
        )
        
        isSelectedRelay
            .bind(to: interactor.isSelectedRelay)
            .disposed(by: disposeBag)
        
        isSelected
            .map(weak: self) { (self, isSelected) -> ImageViewContent in
                guard isSelected else { return .empty }
                let item = self.interactor.item
                return ImageViewContent(
                    imageName: "v-selection-icon",
                    accessibility: .id("\(AccessibilityId.selectionImageViewPrefix)\(item.accessibilityId)")
                )
            }
            .bind(to: selectionImageRelay)
            .disposed(by: disposeBag)
        
        tapRelay
            .withLatestFrom(isSelectedRelay)
            .map { !$0 }
            .bind(to: isSelectedRelay)
            .disposed(by: disposeBag)
    }
    
    func setup(selectionEvent: @escaping () -> Void) {
        isSelected
            .filter { $0 }
            .mapToVoid()
            .bind(onNext: selectionEvent)
            .disposed(by: disposeBag)
    }

    /// An accessor for text pattern search
    func contains(text: String) -> Bool {
        return title.text.lowercased().contains(text) || description.text.lowercased().contains(text)
    }
    
    func deselect() {
        isSelectedRelay.accept(false)
    }
    
    func select() {
        isSelectedRelay.accept(true)
    }
}

// MARK: - Equatable

extension SelectionItemViewPresenter: Equatable, Hashable {
    public static func == (lhs: SelectionItemViewPresenter, rhs: SelectionItemViewPresenter) -> Bool {
        return lhs.interactor == rhs.interactor
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(interactor)
    }
}
