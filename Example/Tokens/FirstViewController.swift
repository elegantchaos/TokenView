//
//  FirstViewController.swift
//  Tokens
//
//  Created by Developer on 23/08/2019.
//  Copyright © 2019 Developer. All rights reserved.
//

import UIKit
import TokenView

class FirstViewController: UIViewController {
    @IBOutlet weak var tagsView: TokenView!
    @IBOutlet weak var statusView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let allTokens = ["foo", "bar", "waffle", "test", "another", "etc"].map({ Token(name: $0) })
        let initialTokens = [allTokens[0], allTokens[2]]
        tagsView.setup(tokens: initialTokens, allTokens: allTokens, delegate: self)
    }
}

extension FirstViewController: TokenViewDelegate {
    func tokenView(_ view: TokenView, changedTokens tokens: [Token]) {
        statusView.text = "Tokens: \(tokens.map({ $0.name }))"
    }
}

