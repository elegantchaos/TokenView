// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Developer on 27/08/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import UIKit

public protocol TokenViewDelegate {
    func tokensChanged(tags: [Token])
}

public class TokenView: UITextView {
    static let tagKey = NSAttributedString.Key(rawValue: "tag")
    
    struct TokenRange {
        let tag: Token
        let range: NSRange
    }

    private var tokenDelegate: TokenViewDelegate?
    
    private var tokens: [Token] = []
    private var allTokens: [Token] = []
    private var currentToken: TokenRange?
    private var wholeToken: TokenRange?

    private var skipSelection = false
    private let separator: Character = " "
    private let separatorString = String(" ")
    
    public let normalTokenColor = UIColor.systemGray
    public let currentTokenColor = UIColor.systemGray2
    public let wholeTokenColor = UIColor.darkGray
   
    func setup(tokens: [Token], allTags: [Token], delegate: TokenViewDelegate) {
        self.tokens = tokens
        self.allTokens = allTags
        self.tokenDelegate = delegate
        self.delegate = self
        self.spellCheckingType = .no
        self.dataDetectorTypes = []

        updateText()
        tokenDelegate?.tokensChanged(tags: tokens)
    }
    
    func updateText() {
        let names = NSMutableAttributedString()
        var baseAttributes: [NSAttributedString.Key:Any] = [:]
        if let font = self.font {
            baseAttributes[NSAttributedString.Key.font] = font
        }

        let spacer = NSAttributedString(string: separatorString, attributes: baseAttributes)
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
    
    func updateTokens() {
        let items = text.split(separator: separator)
        let newTags = items.map({Token(name: String($0))})
        if newTags != tokens {
            tokens = newTags
            updateText()
            tokenDelegate?.tokensChanged(tags: tokens)
            self.setNeedsDisplay()
        }
    }

       public override func draw(_ rect: CGRect) {
           if let context = UIGraphicsGetCurrentContext() {
               let origin = CGPoint(x: textContainerInset.left, y: textContainerInset.top)
               context.saveGState()
               let items = text.split(separator: separator)
               var range = NSRange(location: 0, length: 0)
               for item in items {
                   let string = String(item)
                   range.length = string.count
                   let tagRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                   var rect = layoutManager.boundingRect(forGlyphRange: tagRange, in: textContainer)
                   normalTokenColor.setFill()
                   if let itemTokenRange = tokenRange(at: range) {
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
    
    func tokenRange(at range: NSRange) -> TokenRange? {
        if let attributed = attributedText {
            var effectiveRange = NSRange(location: 0, length: 0)
            if range.location >= 0, range.location < attributed.length, let tag = attributed.attribute(TokenView.tagKey, at: range.location, effectiveRange: &effectiveRange) as? Token {
                return TokenRange(tag: tag, range: effectiveRange)
            }
        }
        
        return nil
    }
    
    func select(token: TokenRange, asWhole: Bool = false, adjustSelection: Bool = false) {
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
    
    func clearSelection() {
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
            textView.insertText(text == " " ? separatorString : text)
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
                textView.insertText(separatorString)
                return false
            }
        }

        return true
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        updateTokens()
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
    }
}
