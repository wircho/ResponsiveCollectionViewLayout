//
//  ViewController.swift
//  ResponsiveCollectionViewSample
//
//  Created by Adolfo Rodriguez on 2014-11-17.
//  Copyright (c) 2014 Wircho. All rights reserved.
//

import UIKit

class ViewController: UICollectionViewController, ResponsiveCollectionViewDataSource, ResponsiveCollectionViewDelegateFlowLayout, ResponsiveCollectionViewLayoutDelegate {
    
    var items:[(CGFloat,UIColor)] = [(100,UIColor.redColor()), (160,UIColor.blueColor()), (50,UIColor.greenColor()),(100,UIColor.yellowColor()), (160,UIColor.orangeColor()), (50,UIColor.cyanColor()),(100,UIColor.purpleColor()), (160,UIColor.grayColor()), (50,UIColor.magentaColor())]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let layout = ResponsiveCollectionViewLayout()
        layout.layoutDelegate = self
        
        self.collectionView.collectionViewLayout = layout
        
        self.collectionView.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        
    }
    
    //MARK: UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell:UICollectionViewCell! = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as? UICollectionViewCell
        cell.backgroundColor = items[indexPath.item].1
        
        if cell.contentView.subviews.count < 1 {
            let label = UILabel()
            label.frame = cell.contentView.bounds
            label.autoresizingMask = .FlexibleWidth | .FlexibleHeight
            label.text = "\(label)"
            cell.contentView.addSubview(label)
        }
        
        return cell
    }
    
    //MARK: ResponsiveCollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, itemAtIndexPath fromIndexPath: NSIndexPath, didMoveToIndexPath toIndexPath: NSIndexPath) {
        
        let item = items.removeAtIndex(fromIndexPath.item)
        items.insert(item, atIndex: toIndexPath.item)
        
    }
    
    //TODO: Add Data Source Handler
    
    //MARK: ResponsiveCollectionViewLayoutDelegate
    
    func suplementaryViewKindsForCollectionView(collectionView:UICollectionView, layout:UICollectionViewLayout) -> [String]
    {
        return []
    }
    
    func decorationViewKindsForCollectionView(collectionView:UICollectionView, layout:UICollectionViewLayout) -> [String]
    {
        return []
    }
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForSuplementaryViewOfKind kind:String, inSection section:Int, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    {
        return CGRectZero
    }
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForDecorationViewOfKind kind:String, inSection section:Int, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    {
        return CGRectZero
    }
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, rectForCellAtIndexPath indexPath:NSIndexPath, afterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGRect
    {
        var rect = CGRectMake(10,30,self.collectionView.bounds.size.width-20, items[indexPath.item].0)
        
        if layoutInfo.cells.count > 0 {
            let lastRect = layoutInfo.cells.last!.last!.frame
            rect.origin.y = lastRect.origin.y + lastRect.size.height + 10
        }
        
        return rect
    }
    
    func collectionView(collectionView:UICollectionView, layout:UICollectionViewLayout, contentSizeAfterLayout layoutInfo:ResponsiveLayoutInfo!) -> CGSize
    {
        return CGSizeMake(collectionView.bounds.size.width,CGFloat(2) * collectionView.bounds.size.height)
    }
    

}

