import UIKit

final class ViewController: UIViewController {

    @IBOutlet private var collectionView: UICollectionView!
    
    // Recommendation #1: make ThemeManager a property
    // instead of recreating it each time
    private let themeManager = ThemeManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.setCollectionViewLayout(UICollectionViewFlowLayout(), animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
}

extension ViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        themeManager.imageKeys.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThemesCollectionViewCell", for: indexPath) as? ThemesCollectionViewCell else {
            fatalError("Unexpected cell class dequeued")
        }
        
        cell.currentIndexPath = indexPath
        
        let cellSize = self.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath)
        themeManager.fetchImage(atIndex: indexPath.item, resizedTo: cellSize) { [weak cell] image, itemIndex in
            guard let cell = cell, let image = image else { return }
            DispatchQueue.main.async {
                guard let cellIndexPath = cell.currentIndexPath, cellIndexPath.item == itemIndex else {
                    print("⚠️ Discarding fetched image for item \(itemIndex) because the cell is no longer being used for that index path")
                    return
                }
                print("Fetched image for \(indexPath) of size \(image.size) and scale \(image.scale)")
                cell.imageView.image = image
                cell.textLabel.text = "\(indexPath)"
            }
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate and UICollectionViewDelegateFlowLayout

extension ViewController: UICollectionViewDelegate {}

extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let sectionInsets = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        return CGSize(width: collectionView.frame.width - sectionInsets.left - sectionInsets.right, height: 128)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        0
    }
}

// MARK: - ThemesCollectionViewCell

final class ThemesCollectionViewCell: UICollectionViewCell {
    @IBOutlet var textLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    var currentIndexPath: IndexPath?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 20
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        currentIndexPath = nil
    }
}

// MARK: - ThemeManager

final class ThemeManager {
    // Recommendation #5: Implement an image cache of resized images inside `ThemeManager`
    private let imageCache = NSCache<NSString, UIImage>()
    
    private(set) var imageKeys: [NSString]
    
    init() {
        imageKeys = []
        for i in 1...40 {
            imageKeys.append(NSString(string: "image\(i)"))
        }
    }
    
    // Recommendation #2: make ThemeManager fetch just one image with a particular index.
    func fetchImage(atIndex index: Int, resizedTo size: CGSize, completion: @escaping (UIImage?, Int) -> Void) {
        guard 0 <= index, index < imageKeys.count else {
            assertionFailure("Image with invalid index requested")
            completion(nil, index)
            return
        }
        
        let imageKey = imageKeys[index]
         
        if let cachedImage = imageCache.object(forKey: imageKey) {
            completion(cachedImage, index)
            return
        }
        
        // Recommendation #3: Make image loading asynchronous, moving the work off the main queue.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil, index)
                return
            }
            guard let image = UIImage(named: String(imageKey)) else {
                assertionFailure("Image is missing from the asset catalog")
                completion(nil, index)
                return
            }
            
            // Recommendation #4: After loading an image from disk, resize it appropriately
            let resizedImage = image.resized(to: size)
            
            self.imageCache.setObject(resizedImage, forKey: imageKey)
            completion(resizedImage, index)
        }
    }
}

// MARK: - Image Resize Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio  = (targetSize.width  / size.width)
        let heightRatio = (targetSize.height / size.height)
        let effectiveRatio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * effectiveRatio, height: size.height * effectiveRatio)
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
