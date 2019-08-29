// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Developer on 27/08/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import UIKit

public protocol TokenViewDelegate {
    func tokenView(_ view: TokenView, updatedTokens tokens: [Token])
    func tokenView(_ view: TokenView, changedTokens tokens: [Token])
    func tokenView(_ view: TokenView, menuItemsForToken: Token) -> [UIMenuItem]
}

extension TokenViewDelegate {
    func tokenView(_ view: TokenView, updatedTokens tokens: [Token]) { }
    func tokenView(_ view: TokenView, changedTokens tokens: [Token]) { }
    func tokenView(_ view: TokenView, menuItemsForToken: Token) -> [UIMenuItem] { return [] }
}

/// UITextView which displays its contents as a sequence of tokens.
///
/// The contents are basically just normal text, but we override the draw method
/// to show a round-rect background behind each token.
///
/// The token names are allowed to contain spaces, which means that we need to
/// use something else to delimit tokens. We use the non breaking space for this,
/// and we trap the user typing a space and do the correct thing depending on context.
///
/// We also trap selection changes, to allow the user to both edit existing tokens and type
/// new ones. If the user positions the cursor directly to the right of a token and hits delete,
/// or moves the cursor left, we select the whole token. A second deletion will delete the token.
/// Moving the cursor when the whole token is selected will instead place the cursor at the end
/// of the token so that individual characters can be deleted.
///

/// TODO: use allTokens to show token suggestions

public class TokenView: UITextView {
    static private let tagKey = NSAttributedString.Key(rawValue: "tag")
    static private let separatorCharacter: Character = "\u{a0}"
    static private let separatorString = String(TokenView.separatorCharacter)

    private struct TokenRange {
        let tag: Token
        let range: NSRange
    }
    
    private var tokenDelegate: TokenViewDelegate?
    
    private var tokens: [Token] = []
    private var allTokens: [Token] = []
    private var currentToken: TokenRange?
    private var wholeToken: TokenRange?
    
    private var skipSelection = false
    
    public let normalTokenColor = UIColor.systemGray2
    public let currentTokenColor = UIColor.systemGray
    public let wholeTokenColor = UIColor.systemGray3
    
    public func setup(tokens: [Token], allTokens: [Token], delegate: TokenViewDelegate) {
        self.tokens = tokens
        self.allTokens = allTokens
        self.tokenDelegate = delegate
        self.delegate = self
        self.spellCheckingType = .no
        self.dataDetectorTypes = []
        self.autocapitalizationType = .none
        
        updateText()
        tokenDelegate?.tokenView(self, updatedTokens: tokens)
        setNeedsDisplay()
    }
    
    
    public override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: textContainerInset.left, y: textContainerInset.top)
            context.saveGState()
            let items = text.split(separator: TokenView.separatorCharacter)
            var range = NSRange(location: 0, length: 0)
            for item in items {
                let string = String(item)
                range.length = string.count
                let tagRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rect = layoutManager.boundingRect(forGlyphRange: tagRange, in: textContainer)
                normalTokenColor.setFill()
                if isEditable, let itemTokenRange = tokenRange(at: range) {
                    if itemTokenRange.tag == wholeToken?.tag {
                        wholeTokenColor.setFill()
                    } else if itemTokenRange.tag == currentToken?.tag {
                        currentTokenColor.setFill()
                    }
                }
                rect.origin.x += origin.x
                rect.origin.y += origin.y
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 4.0)
                path.fill()
                range.location += string.count + 1
            }
            context.restoreGState()
        }
        super.draw(rect)
    }
    
    private func updateText() {
        let names = NSMutableAttributedString()
        var baseAttributes: [NSAttributedString.Key:Any] = [:]
        if let font = self.font {
            baseAttributes[NSAttributedString.Key.font] = font
        }
        
        let spacer = NSAttributedString(string: TokenView.separatorString, attributes: baseAttributes)
        for tag in tokens {
            var attributes = baseAttributes
            attributes[TokenView.tagKey] = tag
            let tagString = NSAttributedString(string: tag.name, attributes: attributes)
            names.append(tagString)
            names.append(spacer)
        }
        
        let selection = selectedRange
        attributedText = names
        selectedRange = selection.clipped(to: names)
    }
    
    private func updateTokens() {
        let items = text.split(separator: TokenView.separatorCharacter)
        let newTags = items.map({Token(name: String($0))})
        if newTags != tokens {
            tokens = newTags
            updateText()
            tokenDelegate?.tokenView(self, updatedTokens: tokens)
            self.setNeedsDisplay()
        }
    }
    
    private func tokenRange(at range: NSRange) -> TokenRange? {
        if let attributed = attributedText {
            var effectiveRange = NSRange(location: 0, length: 0)
            if range.location >= 0, range.location < attributed.length, let tag = attributed.attribute(TokenView.tagKey, at: range.location, effectiveRange: &effectiveRange) as? Token {
                return TokenRange(tag: tag, range: effectiveRange)
            }
        }
        
        return nil
    }
    
    private func select(token: TokenRange, asWhole: Bool = false, adjustSelection: Bool = false) {
        currentToken = token
        if asWhole {
            print("as whole")
            wholeToken = token
            if adjustSelection {
                skipSelection = true
                selectedRange = token.range
            }
        } else {
            wholeToken = nil
        }
        setNeedsDisplay()
    }
    
    private func clearSelection() {
        if currentToken != nil {
            print("clearing selection")
            currentToken = nil
            wholeToken = nil
            setNeedsDisplay()
        }
    }
}

extension TokenView: UITextViewDelegate {
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text != "\n" else {
            return false
        }
        
        if let tokenRange = wholeToken {
            textView.selectedRange = tokenRange.range
            textView.insertText(text == " " ? TokenView.separatorString : text)
            wholeToken = nil
            return false
        }
        
        if (text == "") && (selectedRange.length == 0) {
            print("deleting")
            
            if currentToken == nil, let beforeTag = tokenRange(at: range) {
                select(token: beforeTag, asWhole: true)
                return false
            }
        } else if (text == " ") && (range.length == 0) {
            // inserting a space
            var effectiveRange = NSRange(location: 0, length: 0)
            let attributed = textView.attributedText!
            if range.location < attributed.length, let tag = attributed.attribute(TokenView.tagKey, at: range.location, effectiveRange: &effectiveRange) as? Token {
                print("inserting space in tag \(tag.name)")
            } else {
                print("inserting space")
                textView.insertText(TokenView.separatorString)
                return false
            }
        }
        
        return true
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        updateTokens()
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        tokenDelegate?.tokenView(self, changedTokens: tokens)
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard skipSelection == false else {
            skipSelection = false
            return
        }
        
        var newSelection = textView.selectedRange
        if let wholeRange = wholeToken?.range, wholeRange.length > 0, newSelection.length == 0, newSelection.location == wholeRange.location {
            skipSelection = true
            newSelection = NSRange(location: newSelection.location + wholeRange.length - 1, length: 0)
            selectedRange = newSelection
        }
        
        if let newTokenRange = tokenRange(at: newSelection) {
            print("selection in tag \(newTokenRange.tag.name)")
            let asWhole = (currentToken?.tag != newTokenRange.tag) || (currentToken?.range == newSelection)
            select(token: newTokenRange, asWhole: asWhole, adjustSelection: true)
        } else {
            print("selection not in tag")
            clearSelection()
        }
        
        let menu = UIMenuController.shared
        if let token = currentToken {
            menu.menuItems = tokenDelegate?.tokenView(self, menuItemsForToken: token.tag)
        } else {
            menu.menuItems = []
        }
    }
}
