//
//  AddCardStateService.swift
//  Blockchain
//
//  Created by Daniel Huri on 31/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import RxCocoa
import PlatformKit

final class AddCardStateService {
    
    // MARK: - Types
                
    /// Comprise all the states so far in the current Simple-Buy session
    struct States {
        
        /// The actual state of the flow
        let current: State
        
        /// The previous states sorted chronologically
        let previous: [State]
        
        /// A computed inactive state
        static var inactive: States {
            States(current: .inactive, previous: [])
        }
        
        /// Maps the instance of `States` into a new instance where the appended
        /// state is the current
        func states(byAppending state: State) -> States {
            States(
                current: state,
                previous: previous + [current]
            )
        }

        /// Maps the instance of `States` into a new instance where the last
        /// state is trimmed off. In case `previous` is an empty array, `current` will be
        /// `.inactive`.
        func statesByRemovingLast() -> States {
            States(
                current: previous.last ?? .inactive,
                previous: previous.dropLast()
            )
        }
    }
    
    /// Marks a past or present state in the state-machine
    enum State {
        
        /// Card details screen
        case cardDetails
                        
        /// Billing address screen
        case billingAddress(CardData)
        
        /// Inactive state
        case inactive
    }
    
    enum Action {
        case next(to: State)
        case previous
    }
    
    // MARK: - Properties
    
    var action: Observable<Action> {
        actionRelay
            .observeOn(MainScheduler.instance)
    }
    
    private let statesRelay = BehaviorRelay<States>(value: .inactive)
    private let previousRelay = PublishRelay<Void>()
    
    private let actionRelay = PublishRelay<Action>()
    private let disposeBag = DisposeBag()

    // MARK: - Setup
    
    init() {
        previousRelay
            .observeOn(MainScheduler.instance)
            .bind(weak: self) { (self) in self.previous() }
            .disposed(by: disposeBag)
    }
    
    // MARK: - Basic Navigation
    
    func start() {
        let states = States(current: .cardDetails, previous: [.inactive])
        apply(action: .next(to: states.current), states: states)
    }
    
    func end() {
        let states = statesRelay.value.states(byAppending: .inactive)
        apply(action: .next(to: states.current), states: states)
    }
    
    private func previous() {
        let states = statesRelay.value.statesByRemovingLast()
        apply(action: .previous, states: states)
    }
        
    private func apply(action: Action, states: States) {
        actionRelay.accept(action)
        statesRelay.accept(states)
    }
    
    // MARK: - Other Customized Navigation
    
    func addBillingAddress(to cardData: CardData) {
        let states = statesRelay.value.states(byAppending: .billingAddress(cardData))
        apply(action: .next(to: states.current), states: states)
    }
}
