//
//  ResponsiveCollectionViewLayout.swift
//  ResponsiveCollectionViewSample
//
//  Created by Adolfo Rodriguez on 2014-11-17.
//  Pretty much translated from https://github.com/lxcid/LXReorderableCollectionViewFlowLayout
//
//

import UIKit

//MARK: CGPoint + Operators

public func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

public func += (inout left: CGPoint, right: CGPoint) {
    left = left + right
}

//MARK: Constants

let kRCVScrollingDirectionKey = "RCVScrollingDirection";
let kRCVCollectionViewKeyPath = "collectionView";
var kRCVDLUserInfoHandle: UInt8 = 0
let kRCV_FRAMES_PER_SECOND:CGFloat = 60

//MARK: Extensions

extension CADisplayLink {
    var rcv_userInfo:[String:AnyObject]! {
        get {
            return objc_getAssociatedObject(self, &kRCVDLUserInfoHandle) as [String:AnyObject]!
        }
        set {
            objc_setAssociatedObject(self, &kRCVDLUserInfoHandle, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        }
    }
}

extension UICollectionViewCell {
    var rcv_rasterizedImage:UIImage! {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0)
        self.layer.renderInContext(UIGraphicsGetCurrentContext())
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

//MARK: ResponsiveCollectionViewDataSource Protocol

@objc public protocol ResponsiveCollectionViewDataSource: NSObjectProtocol {
    
    optional func collectionView(collectionView:UICollectionView,itemAtIndexPath fromIndexPath:NSIndexPath, willMoveToIndexPath toIndexPath:NSIndexPath);
    
    optional func collectionView(collectionView:UICollectionView,itemAtIndexPath fromIndexPath:NSIndexPath, didMoveToIndexPath toIndexPath:NSIndexPath);
    
    optional func collectionView(collectionView:UICollectionView,canMoveItemAtIndexPath indexPath:NSIndexPath) -> Bool;
    
    optional func collectionView(collectionView:UICollectionView,itemAtIndexPath fromIndexPath:NSIndexPath, canMoveToIndexPath toIndexPath:NSIndexPath) -> Bool;
}

//MARK: ResponsiveCollectionViewDelegateFlowLayout Protocol

@objc public protocol ResponsiveCollectionViewDelegateFlowLayout: NSObjectProtocol {
    
    optional func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, willBeginDraggingItemAtIndexPath indexPath:NSIndexPath);
    
    optional func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, didBeginDraggingItemAtIndexPath indexPath:NSIndexPath);
    
    optional func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, willEndDraggingItemAtIndexPath indexPath:NSIndexPath);
    
    optional func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, didEndDraggingItemAtIndexPath indexPath:NSIndexPath);
}

//MARK: ResponsiveCollectionViewLayoutDelegate Protocol

@objc public protocol ResponsiveCollectionViewLayoutDelegate: NSObjectProtocol {
    
    func suplementaryViewKindsForCollectionView(collectionView:UICollectionView, layout:UICollectionViewLayout) -> [String]
    
    func decorationViewKindsForCollectionView(collectionView:UICollectionView, layout:UICollectionViewLayout) -> [String]
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForSuplementaryViewOfKind kind:String, inSection section:Int, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForDecorationViewOfKind kind:String, inSection section:Int, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForCellAtIndexPath indexPath:NSIndexPath, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, contentSizeAfterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGSize
    
}

//MARK: Layout Info Class

@objc public class ResponsiveLayoutInfo {
    public var suplementaryViews:[[String:UICollectionViewLayoutAttributes]]! = []
    public var decorationViews:[[String:UICollectionViewLayoutAttributes]]! = []
    public var cells:([[UICollectionViewLayoutAttributes]])! = []
}

//MARK: Collection View Layout Class

public class ResponsiveCollectionViewLayout: UICollectionViewLayout, UIGestureRecognizerDelegate {
    
    public var scrollingSpeed:CGFloat = 300
    public var scrollingTriggerEdgeInsets = UIEdgeInsetsMake(50,50,50,50)
    public var longPressGestureRecognizer:UILongPressGestureRecognizer!
    public var panGestureRecognizer:UIPanGestureRecognizer!
    
    public var layoutDelegate:ResponsiveCollectionViewLayoutDelegate! = nil
    
    private var currentLayoutInfo:ResponsiveLayoutInfo!
    
    enum ScrollingDirection:Int {
        case Unknown
        case Up
        case Down
        case Left
        case Right
    }
    
    var selectedItemIndexPath:NSIndexPath!
    var currentView:UIView!
    var currentViewCenter = CGPointZero
    var panTranslationInCollectionView = CGPointZero
    var displayLink:CADisplayLink!
    
    var dataSource:ResponsiveCollectionViewDataSource! {
        return self.collectionView!.dataSource as? ResponsiveCollectionViewDataSource
        
    }
    
    var delegate:ResponsiveCollectionViewDelegateFlowLayout! {
        return self.collectionView!.delegate as? ResponsiveCollectionViewDelegateFlowLayout
    }
    
    var lDelegate:ResponsiveCollectionViewLayoutDelegate! {
        if self.layoutDelegate != nil {
            return self.layoutDelegate
        }
        return self.collectionView!.delegate as? ResponsiveCollectionViewLayoutDelegate
    }
    
    func setupCollectionView() {
        longPressGestureRecognizer = UILongPressGestureRecognizer(target:self,action:"handleLongPressGesture:")
        longPressGestureRecognizer.delegate = self;
        
        // Links the default long press gesture recognizer to the custom long press gesture recognizer we are creating now
        // by enforcing failure dependency so that they doesn't clash.
        for gestureRecognizer in self.collectionView!.gestureRecognizers! {
            if let gr = gestureRecognizer as? UILongPressGestureRecognizer {
                gr.requireGestureRecognizerToFail(longPressGestureRecognizer)
            }
        }
        
        self.collectionView!.addGestureRecognizer(longPressGestureRecognizer)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action:"handlePanGesture:")
        panGestureRecognizer.delegate = self
        
        self.collectionView!.addGestureRecognizer(panGestureRecognizer)
        
        // Useful in multiple scenarios: one common scenario being when the Notification Center drawer is pulled down
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleApplicationWillResignActive:", name: UIApplicationWillResignActiveNotification, object: nil)
    }
    
    override init() {
        super.init()
        self.addCollectionViewObserver()
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addCollectionViewObserver()
    }
    
    func addCollectionViewObserver() {
        self.addObserver(self, forKeyPath: kRCVCollectionViewKeyPath, options: .New, context: nil)
    }
    
    func applyLayoutAttributes(layoutAttributes:UICollectionViewLayoutAttributes) {
        if layoutAttributes.indexPath? == self.selectedItemIndexPath {
            layoutAttributes.hidden = true
        }
    }
    
    func invalidateLayoutIfNecessary() {
        let newIndexPath:NSIndexPath! = self.collectionView?.indexPathForItemAtPoint(self.currentView.center)
        let previousIndexPath = self.selectedItemIndexPath
        
        if  newIndexPath == nil || newIndexPath.isEqual(previousIndexPath) {
            return;
        }
        
        let canMove = self.dataSource?.collectionView?(self.collectionView!, canMoveItemAtIndexPath:newIndexPath)
        
        if canMove != nil && !(canMove!) {
            return
        }
        
        self.selectedItemIndexPath = newIndexPath
        
        self.dataSource?.collectionView?(self.collectionView!, itemAtIndexPath: previousIndexPath, willMoveToIndexPath: newIndexPath!)
        
        weak var weakSelf = self
        
        self.collectionView!.performBatchUpdates(
            { () -> Void in
                
                if let strongSelf = weakSelf {
                    strongSelf.collectionView!.deleteItemsAtIndexPaths([previousIndexPath])
                    strongSelf.collectionView!.insertItemsAtIndexPaths([newIndexPath])
                    
                    strongSelf.dataSource?.collectionView?(strongSelf.collectionView!, itemAtIndexPath: previousIndexPath, didMoveToIndexPath: newIndexPath)
                    
                    //strongSelf.invalidateLayout()
                }
                
            },
            completion: { (finished:Bool) -> Void in
                
                if let strongSelf = weakSelf {
                    
                    
                    //strongSelf.invalidateLayout()
                    
                }
                
            }
        )
        
    }
    
    func invalidatesScrollTimer() {
        if displayLink == nil {
            return
        }
        if !displayLink.paused {
            displayLink.invalidate();
        }
        displayLink = nil;
    }
    
    func setupScrollTimerInDirection(direction:ScrollingDirection) {
        
        if self.displayLink == nil || !self.displayLink.paused {
            let oldDirection = ScrollingDirection(rawValue:(self.displayLink?.rcv_userInfo?[kRCVScrollingDirectionKey] as? NSNumber)?.integerValue ?? 0)
            
            if direction == oldDirection {
                return;
            }
        }
        
        self.invalidatesScrollTimer()
        
        self.displayLink = CADisplayLink(target: self, selector: "handleScroll:")
        
        self.displayLink.rcv_userInfo = [kRCVScrollingDirectionKey:direction.rawValue]
        
        self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
    }
    
    
    //MARK: Target/Action Methods
    
    func handleScroll(displayLink:CADisplayLink) {
        let direction = ScrollingDirection(rawValue: (displayLink.rcv_userInfo[kRCVScrollingDirectionKey] as? NSNumber)?.integerValue ?? 0)!
        
        if direction == .Unknown {
            return
        }
        
        let frameSize = self.collectionView!.bounds.size;
        let contentSize = self.collectionView!.contentSize;
        let contentOffset = self.collectionView!.contentOffset;
        
        // Important to have an integer `distance` as the `contentOffset` property automatically gets rounded
        // and it would diverge from the view's center resulting in a "cell is slipping away under finger"-bug.
        
        var distance = rint(self.scrollingSpeed / kRCV_FRAMES_PER_SECOND);
        var translation = CGPointZero;
        
        switch direction {
        case .Up:
            distance = -distance
            let minY:CGFloat = 0
            if contentOffset.y + distance <= minY {
                distance -= contentOffset.y
            }
            translation = CGPointMake(0,distance)
        case .Down:
            let maxY = max(contentSize.height,frameSize.height) - frameSize.height
            if contentOffset.y + distance >= maxY {
                distance = maxY - contentOffset.y
            }
            translation = CGPointMake(0,distance)
        case .Left:
            distance = -distance
            let minX:CGFloat = 0
            if contentOffset.x + distance <= minX {
                distance = -contentOffset.x
            }
            translation = CGPointMake(distance,0)
        case .Right:
            let maxX = max(contentSize.width,frameSize.width) - frameSize.width
            if contentOffset.x + distance >= maxX {
                distance = maxX - contentOffset.x
            }
            translation = CGPointMake(distance,0)
        default:
            break
        }
        
        self.currentViewCenter += translation
        
        self.currentView.center = self.currentViewCenter + self.panTranslationInCollectionView
        
        self.collectionView!.contentOffset = contentOffset + translation
        
    }
    
    func handleLongPressGesture(gestureRecognizer:UILongPressGestureRecognizer) {
        
        switch gestureRecognizer.state {
        case .Began:
            
            let currentIndexPath:NSIndexPath! = self.collectionView!.indexPathForItemAtPoint(gestureRecognizer.locationInView(self.collectionView))
            
            if currentIndexPath == nil {
                return
            }
            
            let canMove = self.dataSource?.collectionView?(self.collectionView!, canMoveItemAtIndexPath: currentIndexPath)
            if canMove != nil && !(canMove!) {
                return
            }
            
            self.selectedItemIndexPath = currentIndexPath
            
            self.delegate?.collectionView?(self.collectionView!, layout: self, willBeginDraggingItemAtIndexPath: self.selectedItemIndexPath)
            
            let collectionViewCell:UICollectionViewCell! = self.collectionView!.cellForItemAtIndexPath(self.selectedItemIndexPath!)
            
            if collectionViewCell == nil {
                abort()
            }
            
            self.currentView = UIView(frame: collectionViewCell.frame)
            
            collectionViewCell.highlighted = true
            let highlightedImageView = UIImageView(image: collectionViewCell.rcv_rasterizedImage)
            highlightedImageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
            highlightedImageView.alpha = 1
            
            collectionViewCell.highlighted = false
            let imageView = UIImageView(image: collectionViewCell.rcv_rasterizedImage)
            imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
            imageView.alpha = 0
            
            self.currentView.addSubview(imageView)
            self.currentView.addSubview(highlightedImageView)
            
            self.collectionView!.addSubview(self.currentView)
            
            
            
            self.currentViewCenter = self.currentView.center
            
            weak var weakSelf = self
            
            
            UIView.animateWithDuration(0.3, delay: 0.0, options: .BeginFromCurrentState,
                animations: { () -> Void in
                    if let strongSelf = weakSelf {
                        strongSelf.currentView.transform = CGAffineTransformMakeScale(1,1);
                        highlightedImageView.alpha = 0;
                        imageView.alpha = 1;
                    }
                },
                completion: { (finished:Bool) -> Void in
                    if let strongSelf = weakSelf {
                        highlightedImageView.removeFromSuperview()
                        strongSelf.delegate?.collectionView?(self.collectionView!, layout: self, didBeginDraggingItemAtIndexPath: self.selectedItemIndexPath)
                    }
                }
            )
            self.invalidateLayout()
        case .Cancelled:
            fallthrough
        case .Ended:
            if let currentIndexPath = self.selectedItemIndexPath {
                self.delegate?.collectionView?(self.collectionView!, layout: self, willEndDraggingItemAtIndexPath: currentIndexPath)
                
                self.selectedItemIndexPath = nil
                self.currentViewCenter = CGPointZero
                
                let layoutAttributes = self.layoutAttributesForItemAtIndexPath(currentIndexPath)
                
                weak var weakSelf = self
                
                UIView.animateWithDuration(0.3, delay: 0, options: .BeginFromCurrentState,
                    animations: { () -> Void in
                        if let strongSelf = weakSelf {
                            strongSelf.currentView.transform = CGAffineTransformMakeScale(1,1)
                            strongSelf.currentView.center = layoutAttributes.center
                            
                        }
                    },
                    completion: { (finished:Bool) -> Void in
                        if let strongSelf = weakSelf {
                            strongSelf.currentView.removeFromSuperview()
                            strongSelf.currentView = nil
                            strongSelf.invalidateLayout()
                            self.delegate?.collectionView?(self.collectionView!, layout: self, didEndDraggingItemAtIndexPath: currentIndexPath)
                        }
                    }
                )
            }
        default:
            break
            
            
        }
        
    }
    
    func handlePanGesture(gestureRecognizer:UIPanGestureRecognizer) {
        
        switch gestureRecognizer.state {
        case .Began:
            fallthrough
        case .Changed:
            
            self.panTranslationInCollectionView = gestureRecognizer.translationInView(self.collectionView!)
            let viewCenter = self.currentViewCenter + self.panTranslationInCollectionView
            self.currentView.center = viewCenter
            
            self.invalidateLayoutIfNecessary()
            
            if viewCenter.y < CGRectGetMinY(self.collectionView!.bounds) + self.scrollingTriggerEdgeInsets.top && self.collectionView!.contentOffset.y > 0.5 {
                self.setupScrollTimerInDirection(.Up)
            }else if viewCenter.y > CGRectGetMaxY(self.collectionView!.bounds) - self.scrollingTriggerEdgeInsets.bottom && self.collectionView!.contentOffset.y < self.collectionView!.contentSize.height - self.collectionView!.bounds.size.height - 0.5 {
                self.setupScrollTimerInDirection(.Down)
            }else if viewCenter.x < CGRectGetMinX(self.collectionView!.bounds) + self.scrollingTriggerEdgeInsets.left && self.collectionView!.contentOffset.x > 0.5 {
                self.setupScrollTimerInDirection(.Left)
            }else if viewCenter.x > CGRectGetMaxX(self.collectionView!.bounds) - self.scrollingTriggerEdgeInsets.right && self.collectionView!.contentOffset.x < self.collectionView!.contentSize.width - self.collectionView!.bounds.size.width - 0.5 {
                self.setupScrollTimerInDirection(.Right)
            }else{
                self.invalidatesScrollTimer()
            }
            
        case .Cancelled:
            fallthrough
        case .Ended:
            self.invalidatesScrollTimer()
        default:
            break
        }
        
    }
    
    //MARK: UICollectionViewLayout Overrriden Methods
    
    public override func prepareLayout() {
        
        currentLayoutInfo = ResponsiveLayoutInfo()
        
        let suplementaryKinds = self.lDelegate.suplementaryViewKindsForCollectionView(self.collectionView!, layout: self)
        
        let decorationViewKinds = self.lDelegate.decorationViewKindsForCollectionView(self.collectionView!, layout: self)
        
        let numSections = self.collectionView!.numberOfSections()
        
        for var s = 0; s < numSections; s += 1 {
            
            for kind in suplementaryKinds {
                let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: kind, withIndexPath: NSIndexPath(forItem: 0, inSection: s))
                
                attributes.frame = self.lDelegate.collectionView(self.collectionView!, layout: self, rectForSuplementaryViewOfKind: kind, inSection: s, afterLayout: currentLayoutInfo)
                
                if currentLayoutInfo.suplementaryViews.count <= s {
                    currentLayoutInfo.suplementaryViews.append([:])
                }
                
                currentLayoutInfo.suplementaryViews[s][kind] = attributes
            }
            
            let numCells = self.collectionView!.numberOfItemsInSection(s)
            
            for var c = 0; c < numCells; c += 1 {
                let indexPath = NSIndexPath(forItem: c, inSection: s)
                
                let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
                
                attributes.frame = self.lDelegate.collectionView(self.collectionView!, layout: self, rectForCellAtIndexPath: indexPath, afterLayout: currentLayoutInfo)
                
                if currentLayoutInfo.cells.count <= s {
                    currentLayoutInfo.cells.append([])
                }
                
                currentLayoutInfo.cells[s].append(attributes)
            }
            
            for kind in decorationViewKinds {
                let attributes = UICollectionViewLayoutAttributes(forDecorationViewOfKind: kind, withIndexPath: NSIndexPath(forItem: 0, inSection: s))
                
                attributes.frame = self.lDelegate.collectionView(self.collectionView!, layout: self, rectForDecorationViewOfKind: kind, inSection: s, afterLayout: currentLayoutInfo)
                
                if currentLayoutInfo.decorationViews.count <= s {
                    currentLayoutInfo.decorationViews.append([:])
                }
                
                currentLayoutInfo.decorationViews[s][kind] = attributes
            }
            
        }
        
    }
    
    public override func collectionViewContentSize() -> CGSize {
        return self.lDelegate.collectionView(self.collectionView!, layout: self, contentSizeAfterLayout: self.currentLayoutInfo)
    }
    
    private func _layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        var attributes:[UICollectionViewLayoutAttributes] = []
        
        for array in self.currentLayoutInfo.cells {
            for attr in array {
                if CGRectIntersectsRect(rect,attr.frame) {
                    attributes.append(attr)
                }
            }
        }
        
        for dict in self.currentLayoutInfo.suplementaryViews {
            for (_,attr) in dict {
                if CGRectIntersectsRect(rect,attr.frame) {
                    attributes.append(attr)
                }
            }
        }
        
        for dict in self.currentLayoutInfo.decorationViews {
            for (_,attr) in dict {
                if CGRectIntersectsRect(rect,attr.frame) {
                    attributes.append(attr)
                }
            }
        }
        
        return attributes
    }
    
    private func _layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self.currentLayoutInfo.suplementaryViews[indexPath.section][elementKind]
    }
    
    private func _layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self.currentLayoutInfo.decorationViews[indexPath.section][elementKind]
    }
    
    private func _layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self.currentLayoutInfo.cells[indexPath.section][indexPath.item]
    }
    
    public override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        
        let layoutAttributes = self._layoutAttributesForElementsInRect(rect) as? [UICollectionViewLayoutAttributes]
        
        if let lAttrs = layoutAttributes {
            for attr in lAttrs {
                switch attr.representedElementCategory {
                case .Cell:
                    self.applyLayoutAttributes(attr)
                default:
                    break
                }
            }
        }
        
        return layoutAttributes
    }
    
    public override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        
        let layoutAttributes = self._layoutAttributesForItemAtIndexPath(indexPath)
        
        if let attr = layoutAttributes {
            switch attr.representedElementCategory {
            case .Cell:
                self.applyLayoutAttributes(attr)
            default:
                break
            }
        }
        
        return layoutAttributes
        
    }
    
    public override func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self._layoutAttributesForSupplementaryViewOfKind(elementKind, atIndexPath: indexPath)
    }
    
    public override func layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return self._layoutAttributesForDecorationViewOfKind(elementKind, atIndexPath: indexPath)
    }
    
    //MARK: UIGestureRecognizerDelegate Methods
    
    public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.panGestureRecognizer.isEqual(gestureRecognizer) {
            return (self.selectedItemIndexPath != nil)
        }
        return true
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.longPressGestureRecognizer.isEqual(gestureRecognizer) {
            return self.panGestureRecognizer.isEqual(otherGestureRecognizer)
        }
        
        if self.panGestureRecognizer.isEqual(gestureRecognizer) {
            return self.longPressGestureRecognizer.isEqual(otherGestureRecognizer)
        }
        
        return false
    }
    
    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == kRCVCollectionViewKeyPath {
            if self.collectionView != nil {
                self.setupCollectionView()
            }else{
                self.invalidatesScrollTimer()
            }
        }
    }
    
    public func handleApplicationWillResignActive(note:NSNotification) {
        self.panGestureRecognizer.enabled = false;
        self.panGestureRecognizer.enabled = true;
    }
    
}




















