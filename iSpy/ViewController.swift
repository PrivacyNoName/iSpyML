
import UIKit
import Photos
import CoreML

class ViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    let model = yahoo_nsfw()
    var photos = [[UIImage]]()
    var scores = [[Double]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestAuthorization { [weak self] (success) in
            guard let `self` = self else { return }
            
            if success { self.getPhotos() }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool)->()) {
        guard PHPhotoLibrary.authorizationStatus() != .authorized else {
            completion(true)
            return
        }
        
        PHPhotoLibrary.requestAuthorization{ [weak self] (status) in
            guard let `self` = self else { return }
            
            switch status {
            case .authorized:
                completion(true)
            case .denied,.restricted,.notDetermined:
                let alert = UIAlertController(title: "Warning", message: "The application can not operate without the access to the photo library.", preferredStyle: .alert)
                let settingsAction = UIAlertAction(title: "Change settings", style: .default) { (_) in
                    // todo > send to photo settings
                }
                let quitApp = UIAlertAction(title: "Quit", style: .destructive) { (_) in
                    abort()
                }
                alert.addAction(settingsAction)
                alert.addAction(quitApp)
                self.present(alert, animated: true, completion: nil)
            }
        }
        
    }
    
    private func getPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = true
        var allAlbums: [PHFetchResult<PHCollection>] = []
        
        let albumType: [PHAssetCollectionSubtype] = [
            //        .albumRegular,
            //        .albumSyncedEvent,
            //        .albumSyncedFaces,
            //        .albumSyncedAlbum,
            //        .albumImported,
            //        .albumMyPhotoStream,
            //        .albumCloudShared,
            //        .smartAlbumGeneric,
            //        .smartAlbumPanoramas,
            //        .smartAlbumVideos,
            //        .smartAlbumFavorites,
            //        .smartAlbumTimelapses,
            .smartAlbumAllHidden,
            //        .smartAlbumRecentlyAdded,
            //        .smartAlbumBursts,
            //        .smartAlbumSlomoVideos,
            //        .smartAlbumUserLibrary,
            //        .smartAlbumSelfPortraits,
            //        .smartAlbumScreenshots,
            //        .smartAlbumDepthEffect,
            //        .smartAlbumLivePhotos
        ]
        
        for type in albumType {
            let smartAlbumsCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: type, options: fetchOptions)
            allAlbums.append(smartAlbumsCollection as! PHFetchResult<PHCollection>)
        }
        
        for result in allAlbums {
            
            result.enumerateObjects({ [weak self] (collection, index, _) in
                guard let `self` = self else { return }
                
                var imagesInThisAlbum = [UIImage]()
                var scoreInThisAlbum = [Double]()
                
                if let collection = collection as? PHAssetCollection {
                    let opts = PHFetchOptions()
                    opts.includeHiddenAssets = true
                    
                    print(collection.startDate ?? "nil", collection.endDate ?? "nil", collection.approximateLocation ?? "nil")
                    print(collection.localizedLocationNames)
                    
                    let fetchResult = PHAsset.fetchAssets(in: collection, options: opts)
                    fetchResult.enumerateObjects({[weak self] (asset, _, _) in
                        guard let `self` = self else { return }
                        
                        let thumbnail = asset.thumbnail()
                        imagesInThisAlbum.append(thumbnail)
                        scoreInThisAlbum.append(self.nsfwScore(image: thumbnail))
                        
                        
                    })
                }
                self.photos.append(imagesInThisAlbum)
                self.scores.append(scoreInThisAlbum)
                
            })
        }
    }
    
    func nsfwScore(image: UIImage) -> Double {
        guard let probability = try? self.model.prediction(data: image.pixelBuffer()) else {
            fatalError("Unexpected runtime error.")
        }
        let nsfwScore = ceil(probability.featureValue(for: "prob")!.multiArrayValue![[0,0,1,0,0]].doubleValue * 100)
        return nsfwScore
    }
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ItemCell", for: indexPath) as! PhotoCell
        let image = photos[indexPath.section][indexPath.item]
        let score = scores[indexPath.section][indexPath.item]
        
        cell.imageView.image = image
        cell.label.text = "\(score)"
        cell.label.textColor = score >= 20 ? UIColor.red : UIColor.black
        
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos[section].count
    }
}

extension PHAsset {
    func thumbnail() -> UIImage {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.resizeMode = .exact
        option.isNetworkAccessAllowed = true
        option.deliveryMode = .highQualityFormat
        option.isSynchronous = true
        
        var thumbnail = UIImage()
        
        manager.requestImage(for: self, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFit, options: option, resultHandler: {(result, info)->Void in
            thumbnail = result!
        })
        
        return thumbnail
    }
}
